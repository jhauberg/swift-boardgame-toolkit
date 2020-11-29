import Foundation

public struct SheetDescription {
    let author: String?
    let copyright: String?

    public init(
        author: String? = nil,
        copyright: String? = nil
    ) {
        self.author = author
        self.copyright = copyright
    }
}

public enum SheetError: Error {
    case outOfBounds(size: Size)
    case notLaidOut(amount: Int)
}

public struct Sheet {
    public let description: SheetDescription?

    let bundle: Bundle?

    public init(
        description: SheetDescription? = nil,
        bundle: Bundle? = nil
    ) {
        self.description = description
        self.bundle = bundle
    }

    public func images(type: ImageType, configuration: ImageConfiguration) throws {
        guard !configuration.components.isEmpty else {
            print("warning: configuration did not provide any components; no images generated")
            return
        }
        switch type {
        case let .individual(url):
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )

            guard let renderTemplateUrl = Bundle.module.resourceURL?
                .appendingPathComponent("templates/render/index.html"),
                let renderTemplate = try? String(contentsOf: renderTemplateUrl, encoding: .utf8)
            else {
                return
            }

            let delegate = BrowserDelegate(
                template: renderTemplate,
                url: url,
                resourceURL: bundle?.resourceURL,
                components: configuration.components
            )
            delegate.dpi = Double(configuration.dpi)
            delegate.renderNext()

            let runLoop = RunLoop.current

            while delegate.shouldKeepRunning,
                  runLoop.run(mode: .default,
                              before: .distantFuture) {}

        case .tts:
            fatalError("not implemented yet")
        }
    }

    public func document(type: DocumentType, configuration: DocumentConfiguration) throws {
        guard !configuration.layouts.isEmpty else {
            print("warning: configuration did not provide any layouts; document not generated")
            return
        }
        switch type {
        case let .web(url):
            let pages = try arrange(using: configuration)

            let siteUrl = url.appendingPathComponent("site")
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? FileManager.default.removeItem(at: siteUrl)
            guard let templateSiteUrl = Bundle.module.resourceURL?
                .appendingPathComponent("templates/site")
            else {
                fatalError()
            }
            try FileManager.default.copyItem(at: templateSiteUrl, to: siteUrl)
            if let assetsUrl = bundle?.resourceURL?.appendingPathComponent("assets") {
                try FileManager.default.copyItem(
                    at: assetsUrl, to: siteUrl.appendingPathComponent("assets")
                )
            }

            let indexUrl = siteUrl.appendingPathComponent("index.html")
            let index = try String(contentsOf: indexUrl, encoding: .utf8)

            let doc = Element.document(
                template: index,
                paper: configuration.paper,
                pages: pages,
                author: description?.author ?? "",
                description: description?.copyright ?? ""
            )
            try doc.html.write(to: indexUrl, atomically: true, encoding: .utf8)

            let cssUrl = siteUrl.appendingPathComponent("index.css")
            let css = try String(contentsOf: cssUrl, encoding: .utf8)
                .replacingOccurrences(
                    of: "{{page_width}}", with: configuration.paper.extent.width.css
                )
                .replacingOccurrences(
                    of: "{{page_height}}", with: configuration.paper.extent.height.css
                )
            try css.write(to: cssUrl, atomically: true, encoding: .utf8)

            print("saved site at \(siteUrl)")

        case let .pdf(url):
            let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("swift-boardgame-toolkit")
            try FileManager.default.createDirectory(
                at: tempUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )

            try document(type: .web(at: tempUrl), configuration: configuration)
            let siteUrl = tempUrl.appendingPathComponent("site")

            let delegate = BrowserDelegatePDF(destinationUrl: url)
            delegate.paperSize = configuration.paper
            try delegate.load(siteUrl: siteUrl)

            let runLoop = RunLoop.current

            while delegate.shouldKeepRunning,
                  runLoop.run(mode: .default,
                              before: .distantFuture) {}

            try FileManager.default.removeItem(at: tempUrl) // clean up
        }
    }

    private func arrange(using configuration: DocumentConfiguration) throws -> [Page] {
        let allComponents: [Component] = configuration.layouts.flatMap {
            $0.components(orderedBy: .frontsThenBacks)
        }

        if let component = allComponents.first(
            where: { $0.portraitOrientedExtent.width > configuration.paper.innerBounds.width ||
                $0.portraitOrientedExtent.height > configuration.paper.innerBounds.height
            }
        ) {
            // a component won't fit on a page inside bounds
            throw SheetError.outOfBounds(size: component.portraitOrientedExtent)
        }

        var pages: [Page] = []

        for layout in configuration.layouts.splitBySize {
            switch layout.method {
            case let .natural(order, gap):
                // natural layout is left-to-right
                let components = layout.components(orderedBy: order).map { component in
                    component
                        .withOverlays()
                        .withMarks(style: .crosshair(color: "grey"))
                }

                let laidOutPages = components.arrangedLeftToRight(
                    spacing: gap,
                    on: configuration.paper
                )

                pages.append(contentsOf: laidOutPages)
                
            case let .duplex(gap, guides):
                // similar to natural layout, except backs are reversed (i.e. right-to-left)
                // and separated to interleaved pages
                let fronts: [Component] = layout.components.map { component in
                    let front = component.withOverlays()
                    switch guides {
                    case .front,
                         .frontAndBack:
                        return front.withMarks(style: .crosshair(color: "grey"))
                    case .back,
                         .none:
                        return front
                    }
                }

                let laidOutPages = fronts.arrangedLeftToRight(
                    spacing: gap,
                    on: configuration.paper
                )

                let interleavedPages = laidOutPages.interleavingBackPages { components in
                    let backs: [Component] = components.map { back in
                        // note that non-empty backs already have overlays applied at this point
                        switch guides {
                        case .back,
                             .frontAndBack:
                            return back.withMarks(style: .crosshair(color: "grey"))
                        case .front,
                             .none:
                            return back
                        }
                    }
                    return backs.arrangedLeftToRight(
                        spacing: gap,
                        on: configuration.paper,
                        reverse: true
                    )
                }

                if interleavedPages.count % 2 != 0 {
                    // duplex printing requires an even number of pages;
                    // for every page of fronts a page of backs must follow
                    fatalError()
                }

                pages.append(contentsOf: interleavedPages)

            case let .fold(gap, gutter, guides):
                let fronts: [Component] = layout.components(orderedBy: .skippingBacks).map { component in
                    let front = component.withOverlays()
                    switch guides {
                    case .front,
                         .frontAndBack:
                        return front.withMarks(style: .crosshair(color: "grey"))
                    case .back,
                         .none:
                        return front
                    }
                }

                guard let ref = fronts.first else {
                    fatalError()
                }

                // determine the upper part of the paper in which we can layout components
                // note that the extent of this boundary does not go from bleed edge to fold,
                // but from trim edge to fold; i.e. there may be less distance from bleed to
                // fold than what is specified by `gutter`; this is intentional
                let boundedSize = Size(
                    width: configuration.paper.innerBounds.width,
                    height: (
                        ((configuration.paper.innerBounds.height / 2) - gutter) +
                            ref.zone.real.bottom
                    )
                )

                guard ref.portraitOrientedExtent.width <= boundedSize.width,
                      ref.portraitOrientedExtent.height <= boundedSize.height else {
                    // not enough space to put even a single component onto paper
                    // given paper margin, component size and gutter distance
                    fatalError()
                }

                // layout components in "pages" based on a marginless paper specification
                // exactly fitting the previously determined boundaries
                let upperPages = fronts.arrangedLeftToRight(
                    spacing: gap, on: Paper(boundedSize, .zero))

                for arrangedPage in upperPages {
                    let page = Page(size: configuration.paper.extent)
                    let b = arrangedPage.boundingBox
                    let foldOffset = b.height - ref.zone.real.bottom + gutter

                    page.fold(
                        // add a fold guide going across the entire paper, inside margins
                        x: .zero - ((configuration.paper.innerBounds.width / 2) - (b.width / 2)),
                        // note that Fold adjusts to center itself on the coordinate
                        // so we don't have to take that into account here
                        y: foldOffset,
                        distance: configuration.paper.innerBounds.width,
                        vertically: false
                    )

                    for case let .component(component, x, y, r) in arrangedPage.elements {
                        page.arrange(component, x: x, y: y, rotatedBy: r)
                        var back = component.back?.withOverlays() ?? component.empty
                        switch guides {
                        case .back,
                             .frontAndBack:
                            back = back.withMarks(style: .crosshair(color: "grey"))
                        case .front,
                             .none:
                            break
                        }
                        let turns: Layout.Turn?
                        if component.zone.full.extent.height > component.zone.full.extent.width {
                            // flip portrait-oriented components vertically so that
                            // they fold on the bottom edge
                            turns = .cw(.twice)
                        } else {
                            // don't flip landscape-oriented components;
                            // these fold on left/right edges and end up in same orientation
                            turns = nil
                        }
                        page.arrange(back, x: x, y: (y + foldOffset - ref.zone.real.bottom) + gutter, rotatedBy: turns)
                    }

                    pages.append(page)
                }

            case let .custom(order, arrangements):
                guard let _ = arrangements.first(where: { arrangement -> Bool in
                    if case .placement = arrangement.kind {
                        return true
                    }
                    return false
                }) else {
                    // don't run indefinitely
                    fatalError("no placements in this arrangement")
                }
                var components: [Component] = layout.components(orderedBy: order)
                    .reversed() // reversed because we will be using popLast to empty the array
                // but still want the components in original order

                while !components.isEmpty { // repeat until we've arranged all components
                    var page = Page(size: configuration.paper.extent, mode: .relativeToPageMargins)

                    for arrangement in arrangements {
                        switch arrangement.kind {
                        case let .placement(rotation):
                            guard let component = components.popLast() else {
                                // all components have been arranged; continue until gone through
                                // all arrangements (there might still be cuts/folds left)
                                continue
                            }

                            guard let offset = arrangement.offset else {
                                print("warning: missing offset")
                                continue
                            }
                            page.arrange(
                                component
                                    .withOverlays()
                                    .withMarks(style: .crosshair(color: "grey")),
                                x: offset.width,
                                y: offset.height,
                                rotatedBy: rotation
                            )
                        case .pagebreak:
                            pages.append(page)
                            page = Page(
                                size: configuration.paper.extent,
                                mode: .relativeToPageMargins
                            )
                        case let .cut(distance, vertically):
                            guard let offset = arrangement.offset else {
                                print("warning: missing offset")
                                continue
                            }
                            page.cut(
                                x: offset.width,
                                y: offset.height,
                                distance: distance,
                                vertically: vertically
                            )
                        case let .fold(distance, vertically):
                            guard let offset = arrangement.offset else {
                                print("warning: missing offset")
                                continue
                            }
                            page.fold(
                                x: offset.width,
                                y: offset.height,
                                distance: distance,
                                vertically: vertically
                            )
                        }
                    }

                    pages.append(page)
                }
            }
        }

        return pages
    }
}

private extension Array where Element == Layout {
    // if a layout contains mixed-size components, this splits the layouts up into separate,
    // individual layouts, ultimately forcing page-breaks so that every page contains
    // only one size of component
    var splitBySize: [Layout] {
        var sanitizedLayouts: [Layout] = []
        for layout in self {
            if case .custom = layout.method {
                // don't mess with this type of layout; mixing sizes is allowed here
                sanitizedLayouts.append(layout)
                continue
            }
            var previousComponentSize: Size?
            var collected: [Component] = []
            var chunks: [[Component]] = []
            for component in layout.components {
                if let previousSize = previousComponentSize,
                   previousSize.width != component.portraitOrientedExtent.width ||
                   previousSize.height != component.portraitOrientedExtent.height
                {
                    chunks.append(collected)
                    collected = []
                }

                collected.append(component)

                previousComponentSize = component.portraitOrientedExtent
            }
            if !collected.isEmpty {
                chunks.append(collected)
                collected = []
            }
            for chunk in chunks {
                sanitizedLayouts.append(Layout(chunk, method: layout.method))
            }
        }
        return sanitizedLayouts
    }
}

private extension Array where Element == Page {
    func interleavingBackPages(layout: ([Component]) -> [Page]) -> [Page] {
        var interleavedPages: [Page] = []
        for page in self {
            let components: [Component] = page.components.compactMap {
                if case let .component(c, _, _, _) = $0 {
                    return c
                } else {
                    return nil
                }
            }

            guard let _ = components.first(where: { $0.back != nil }) else {
                // at least one component on this page must have a back to proceed;
                // otherwise append a blank page and skip to next
                interleavedPages.append(page)
                // for duplex printing, the number of pages must be even;
                // i.e. we must interleave a blank piece of paper for the remaining
                // back pages to print properly
                interleavedPages.append(Page(size: page.extent))
                continue
            }

            var backs: [Component] = []
            for component in components {
                if let back = component.back {
                    backs.append(back.withOverlays())
                } else {
                    backs.append(component.empty)
                }
            }

            let duplexedPages = layout(backs)
            guard duplexedPages.count == 1, let backPage = duplexedPages.first else {
                // if we somehow end up with more than one page, something went wrong
                fatalError()
            }

            interleavedPages.append(page)
            interleavedPages.append(backPage)
        }
        return interleavedPages
    }
}

private extension Array where Element == Component {
    func arrangedLeftToRight(
        spacing: Measurement<UnitLength>,
        on paper: Paper,
        reverse: Bool = false
    ) -> [Page] {
        precondition(spacing.value >= 0)

        var pages: [Page] = []

        let origin = Size(width: .zero, height: .zero)

        // in this context, x corresponds to the top-left corner of a component
        var x = origin.width
        var y = origin.height

        var page = Page(size: paper.extent)
        var content: [(Size, Component)] = []

        let pagebreak: (Bool) -> Void = { more in
            var offsets: [Size] = []
            for (offset, component) in content {
                offsets.append(Size(width: offset.width, height: offset.height))
                offsets.append(Size(width: offset.width + component.portraitOrientedExtent.width,
                                    height: offset.width + component.portraitOrientedExtent.height))
            }

            let bb = Size.containingOffsets(offsets)

            for (offset, component) in content {
                if reverse {
                    page.arrange(component,
                                 x: bb.width - offset.width - component.portraitOrientedExtent.width,
                                 y: offset.height)
                } else {
                    page.arrange(component,
                                 x: offset.width,
                                 y: offset.height)
                }
            }

            content = []

            pages.append(page)

            if more {
                page = Page(size: paper.extent)
                x = origin.width
                y = origin.height
            }
        }

        for component in self {
            let offset = Size(width: x, height: y)

            // temporarily store offset and component before laying out on page;
            // this is necessary to, at pagebreak, determine actual position on page
            // if we were always just laying out left-to-right, we would not have to do this
            // and could put it on page immediately; however, to determine the relative origin
            // for a layout flowing right-to-left, we have to first figure out just how wide
            // the relative boundary actually is
            content.append((offset, component))

            // increment positions
            x = offset.width + (component.portraitOrientedExtent.width + spacing)

            // note using 'x', not offset.width
            let nextRightEdge = x + component.portraitOrientedExtent.width
            if nextRightEdge > paper.innerBounds.width {
                // next line
                x = origin.width
                y = offset.height + (component.portraitOrientedExtent.height + spacing)
            }

            // note using 'y', not offset.height
            let nextBottomEdge = y + component.portraitOrientedExtent.height
            if nextBottomEdge > paper.innerBounds.height {
                // next page
                pagebreak(true)
            }
        }

        if !content.isEmpty {
            pagebreak(false)
        }

        return pages
    }
}
