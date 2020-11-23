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

public final class Sheet {
    public final let meta: SheetDescription?

    let resourceURL: URL?

    public init(
        description: SheetDescription? = nil,
        resourceURL: URL? = nil
    ) {
        meta = description
        self.resourceURL = resourceURL
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
        let hasGap = spacing > 0.inches || c.innerRect.left > 0.inches
        // note: assuming every component is identically sized on this page!
        let b = page.boundingBox
        let rows = Int(b.height.converted(to: .inches).value / c.portraitOrientedBounds.height
            .converted(to: .inches).value) + (hasGap ? 0 : 1)
        let columns = Int(b.width.converted(to: .inches).value / c.portraitOrientedBounds.width
            .converted(to: .inches).value) + (hasGap ? 0 : 1)

        // note that this also produce cut guides for empty slots
        for row in 0 ..< rows {
            let y = (c.portraitOrientedBounds.height * Double(row)) + (spacing * Double(row))

            page.cut(
                // top
                x: 0.inches - guideLength, y: y + c.innerRect.top,
                distance: b.width + guideLength * 2
            )

            if hasGap {
                page.cut(
                    // bottom
                    x: 0.inches - guideLength,
                    y: y + c.portraitOrientedBounds.height - c.innerRect.top,
                    distance: b.width + guideLength * 2
                )
            }
        }

        for column in 0 ..< columns {
            let x = (c.portraitOrientedBounds.width * Double(column)) + (spacing * Double(column))

            page.cut(
                // left
                x: x + c.innerRect.left, y: 0.inches - guideLength,
                distance: b.height + guideLength * 2,
                vertically: true
            )

            if hasGap {
                page.cut(
                    // right
                    x: x + c.portraitOrientedBounds.width - c.innerRect.left,
                    y: 0.inches - guideLength,
                    distance: b.height + guideLength * 2,
                    vertically: true
                )
            }
        }
    }

    private func layoutLeftToRight(
        components: [Component],
        spacing: Measurement<UnitLength>,
        on paper: Paper,
        reverse: Bool = false,
        applying cuts: @escaping (Page, Measurement<UnitLength>) -> Void
    ) -> [Page] {
        precondition(spacing.value >= 0)

        var pages: [Page] = []

        let origin = Size(width: 0.inches, height: 0.inches)

        // in this context, x corresponds to the top-left corner of a component
        var x = origin.width
        var y = origin.height

        var page = Page(size: paper.size)
        var content: [(Size, Component)] = []

        let pagebreak: (Bool) -> Void = { more in
            var offsets: [Size] = []
            for (offset, component) in content {
                offsets.append(Size(width: offset.width, height: offset.height))
                offsets.append(Size(width: offset.width + component.portraitOrientedBounds.width,
                                    height: offset.width + component.portraitOrientedBounds.height))
            }

            let bb = Size.containingOffsets(offsets)

            for (offset, component) in content {
                if reverse {
                    page.component(component,
                                   x: bb.width - offset.width - component.portraitOrientedBounds
                                       .width,
                                   y: offset.height)
                } else {
                    page.component(component,
                                   x: offset.width,
                                   y: offset.height)
                }
            }

            content = []
            cuts(page, spacing)

            pages.append(page)

            if more {
                page = Page(size: paper.size)
                x = origin.width
                y = origin.height
            }
        }

        for component in components {
            let offset = Size(width: x, height: y)

            // temporarily store offset and component before laying out on page;
            // this is necessary to, at pagebreak, determine actual position on page
            // if we were always just laying out left-to-right, we would not have to do this
            // and could put it on page immediately; however, to determine the relative origin
            // for a layout flowing right-to-left, we have to first figure out just how wide
            // the relative boundary actually is
            content.append((offset, component))

            // increment positions
            x = offset.width + (component.portraitOrientedBounds.width + spacing)

            let nextRightEdge = x + component.portraitOrientedBounds
                .width // note using 'x', not offset.width
            if nextRightEdge > paper.bounds.width {
                // next line
                x = origin.width
                y = offset.height + (component.portraitOrientedBounds.height + spacing)
            }

            let nextBottomEdge = y + component.portraitOrientedBounds
                .height // note using 'y', not offset.height
            if nextBottomEdge > paper.bounds.height {
                // next page
                pagebreak(true)
            }
        }

        if !content.isEmpty {
            pagebreak(false)
        }

        return pages
    }

    private func sanitize(layouts: [Layout]) -> [Layout] {
        var sanitizedLayouts: [Layout] = []
        for layout in layouts {
            switch layout.method {
            case .custom:
                // don't mess with these; they should allow whatever is provided to them
                // i.e. mixing sizes is possible only for these two particular methods
                sanitizedLayouts.append(layout)
                continue
            default:
                break
            }
            var previousComponentSize: Size?
            var collected: [Component] = []
            var chunks: [[Component]] = []
            for component in layout.components {
                if let previousSize = previousComponentSize,
                   previousSize.width != component.portraitOrientedBounds.width ||
                   previousSize.height != component.portraitOrientedBounds.height
                {
                    chunks.append(collected)
                    collected = []
                }

                collected.append(component)

                previousComponentSize = component.portraitOrientedBounds
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

    private func organize(using configuration: DocumentConfiguration) throws -> [Page] {
        let bounds = Size(
            width: configuration.paper.size.width - configuration.paper.margin.width * 2,
            height: configuration.paper.size.height - configuration.paper.margin.height * 2
        )

        let allComponents: [Component] = configuration.layouts.flatMap {
            $0.components(orderedBy: .frontsThenBacks)
        }

        if let component = allComponents.first(
            where: { $0.portraitOrientedBounds.width > bounds.width ||
                $0.portraitOrientedBounds.height > bounds.height
            }
        ) {
            // a component won't fit on a page inside bounds
            throw SheetError.outOfBounds(size: component.portraitOrientedBounds)
        }

        var pages: [Page] = []

        let layouts = sanitize(layouts: configuration.layouts)

        for layout in layouts {
            switch layout.method {
            case let .natural(order, gap):
                // natural layout is left-to-right
                let components = layout.components(orderedBy: order)

                let laidOutPages = layoutLeftToRight(
                    components: components,
                    spacing: gap,
                    on: configuration.paper,
                    applying: cutGuideGrid
                )

                pages.append(contentsOf: laidOutPages)
            case let .duplex(gap):
                // similar to natural layout, except backs are reversed (i.e. right-to-left)
                // and separated to interleaved pages
                let fronts = layout.components

                let laidOutPages = layoutLeftToRight(
                    components: fronts,
                    spacing: gap,
                    on: configuration.paper,
                    applying: cutGuideGrid
                )

                let interleavedPages = interleaveBackPages(for: laidOutPages) { backs in
                    layoutLeftToRight(
                        components: backs,
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
                    fatalError("no placements in this preset") // otherwise we could run infinitely
                }
                var components: [Component] = layout.components(orderedBy: order)
                    .reversed() // reversed because we will be using popLast to empty the array
                // but still want the components in original order

                while !components.isEmpty { // repeat until we've arranged all components
                    var page = Page(size: configuration.paper.size, mode: .relativeToPageMargins)

                    for arrangement in arrangements {
                        let offset = arrangement.offset

                        switch arrangement.kind {
                        case let .placement(breaks, rotation):
                            guard let component = components.popLast() else {
                                // all components have been arranged; continue until gone through
                                // all arrangements (there might still be cuts/folds left)
                                continue
                            }

                            page.component(
                                component,
                                x: offset.width,
                                y: offset.height,
                                rotatedBy: rotation
                            )

                            if breaks {
                                pages.append(page)
                                page = Page(
                                    size: configuration.paper.size,
                                    mode: .relativeToPageMargins
                                )
                            }
                        case let .cut(distance, vertically):
                            page.cut(
                                x: offset.width,
                                y: offset.height,
                                distance: distance,
                                vertically: vertically
                            )
                        case let .fold(distance, vertically):
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

    private func interleaveBackPages(for pages: [Page], layout: ([Component]) -> [Page]) -> [Page] {
        var interleavedPages: [Page] = []
        for page in pages {
            let components: [Component] = page.components.compactMap {
                if case let .component(c, _, _, _) = $0 {
                    return c
                } else {
                    return nil
                }
            }

            guard let referenceComponent = components.first(where: { $0.back != nil }) else {
                // at least one component on this page must have a back to proceed;
                // otherwise append a blank page and skip to next
                interleavedPages.append(page)
                // for duplex printing, the number of pages must be even;
                // i.e. we must interleave a blank piece of paper for the remaining
                // back pages to print properly

                interleavedPages.append(Page(size: page.bounds))
                continue
            }

            var backs: [Component] = []
            for component in components {
                if let back = component.back {
                    backs.append(back)
                } else {
                    backs.append(
                        // empty back; note intentionally not init'ed with overlay
                        Component(size: referenceComponent.portraitOrientedBounds,
                                  // bounds include bleed/trim already
                                  bleed: 0.inches,
                                  trim: 0.inches)
                    )
                }
            }

            let duplexedPages = layout(backs)

            guard duplexedPages.count == 1,
                  let backPage = duplexedPages.first
            else {
                // if we somehow end up with more than one page, something went wrong
                fatalError()
            }

            interleavedPages.append(page)
            interleavedPages.append(backPage)
        }
        return interleavedPages
    }

    public func images(type: ImageType, configuration: ImageConfiguration) throws {
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
                resourceURL: resourceURL,
                components: configuration.components
            )
            delegate.dpi = configuration.dpi
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
        switch type {
        case let .web(url):
            let pages = try organize(using: configuration)

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
            if let assetsUrl = resourceURL?.appendingPathComponent("assets") {
                try FileManager.default.copyItem(
                    at: assetsUrl, to: siteUrl.appendingPathComponent("assets")
                )
            }

            let indexUrl = siteUrl.appendingPathComponent("index.html")

            var innerHtml = ""
            for page in pages {
                innerHtml += Element.page(page, margin: configuration.paper.margin).html
            }

            let index = try String(contentsOf: indexUrl, encoding: .utf8)
                .replacingOccurrences(of: "{{author}}", with: "name")
                .replacingOccurrences(of: "{{description}}", with: "descriptive text")
                .replacingOccurrences(
                    of: "{{generator}}",
                    with: "swift-boardgame-toolkit \(BoardgameKit.version)")
                .replacingOccurrences(
                    of: "{{page_dimensions}}",
                    with: "\(configuration.paper.size.width) by \(configuration.paper.size.height)"
                )
                .replacingOccurrences(of: "{{pages}}", with: innerHtml)

            try index.write(to: indexUrl, atomically: true, encoding: .utf8)

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
}
