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

        case .tts(_):
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
                description: description?.copyright ?? "")
            try doc.html.write(to: indexUrl, atomically: true, encoding: .utf8)

            let cssUrl = siteUrl.appendingPathComponent("index.css")
            let css = try String(contentsOf: cssUrl, encoding: .utf8)
                .replacingOccurrences(of: "{{page_width}}", with: configuration.paper.extent.width.css)
                .replacingOccurrences(of: "{{page_height}}", with: configuration.paper.extent.height.css)
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
                let components = layout.components(orderedBy: order)

                let laidOutPages = components.arrangedLeftToRight(
                    spacing: gap,
                    on: configuration.paper,
                    applying: cutGuideGrid
                )

                pages.append(contentsOf: laidOutPages)
            case let .duplex(gap):
                // similar to natural layout, except backs are reversed (i.e. right-to-left)
                // and separated to interleaved pages
                let fronts = layout.components

                let laidOutPages = fronts.arrangedLeftToRight(
                    spacing: gap,
                    on: configuration.paper,
                    applying: cutGuideGrid
                )

                let interleavedPages = laidOutPages.interleavedWithBackPages { backs in
                    backs.arrangedLeftToRight(
                        spacing: gap,
                        on: configuration.paper,
                        reverse: true,
                        applying: cutGuideGrid
                    )
                }

                if interleavedPages.count % 2 != 0 {
                    // duplex printing requires an even number of pages;
                    // for every page of fronts a page of backs must follow
                    fatalError()
                }

                pages.append(contentsOf: interleavedPages)

            case .fold(_, _):
                fatalError("not implemented yet")

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
                                component,
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

    private func cutGuideGrid(page: Page, spacing: Measurement<UnitLength>) {
        guard case let .component(c, _, _, _) = page.components.first else {
            return
        }

        let guideLength = 4.millimeters // distance beyond bounding box

        // determine whether we should produce cut guides on either side of component
        // if there is no gap or bleed, we can get away with only producing left/top
        // cut guides, plus an additional guide for the last row/column
        // otherwise we need to produce cut guides for all edges of the component
        let hasGap = spacing > .zero || c.zone.real.left > .zero
        // note: assuming every component is identically sized on this page!
        let b = page.boundingBox
        let rows = Int(b.height.converted(to: .inches).value / c.portraitOrientedExtent.height
                        .converted(to: .inches).value) + (hasGap ? 0 : 1)
        let columns = Int(b.width.converted(to: .inches).value / c.portraitOrientedExtent.width
                            .converted(to: .inches).value) + (hasGap ? 0 : 1)

        // note that this also produce cut guides for empty slots
        for row in 0 ..< rows {
            let y = (c.portraitOrientedExtent.height * Double(row)) + (spacing * Double(row))

            page.cut(
                // top
                x: .zero - guideLength, y: y + c.zone.real.top,
                distance: b.width + guideLength * 2
            )

            if hasGap {
                page.cut(
                    // bottom
                    x: .zero - guideLength,
                    y: y + c.portraitOrientedExtent.height - c.zone.real.top,
                    distance: b.width + guideLength * 2
                )
            }
        }

        for column in 0 ..< columns {
            let x = (c.portraitOrientedExtent.width * Double(column)) + (spacing * Double(column))

            page.cut(
                // left
                x: x + c.zone.real.left, y: .zero - guideLength,
                distance: b.height + guideLength * 2,
                vertically: true
            )

            if hasGap {
                page.cut(
                    // right
                    x: x + c.portraitOrientedExtent.width - c.zone.real.left,
                    y: .zero - guideLength,
                    distance: b.height + guideLength * 2,
                    vertically: true
                )
            }
        }
    }
}

fileprivate extension Array where Element == Layout {
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

fileprivate extension Array where Element == Page {
    func interleavedWithBackPages(layout: ([Component]) -> [Page]) -> [Page] {
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
                    backs.append(back)
                } else {
                    backs.append(
                        // empty back, sized to match
                        Component(size: component.zone.full.extent,
                                  // size include bleed/trim already
                                  bleed: .zero,
                                  trim: .zero)
                    )
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

fileprivate extension Array where Element == Component {
    func arrangedLeftToRight(
        spacing: Measurement<UnitLength>,
        on paper: Paper,
        reverse: Bool = false,
        applying cuts: @escaping (Page, Measurement<UnitLength>) -> Void
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
            cuts(page, spacing)

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

            let nextRightEdge = x + component.portraitOrientedExtent
                .width // note using 'x', not offset.width
            if nextRightEdge > paper.innerBounds.width {
                // next line
                x = origin.width
                y = offset.height + (component.portraitOrientedExtent.height + spacing)
            }

            let nextBottomEdge = y + component.portraitOrientedExtent
                .height // note using 'y', not offset.height
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
