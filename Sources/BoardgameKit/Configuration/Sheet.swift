import Foundation

public struct SheetDescription {
    let title: String?
    let author: String?
    let copyright: String?

    public init(
        title: String? = nil,
        author: String? = nil,
        copyright: String? = nil
    ) {
        self.title = title
        self.author = author
        self.copyright = copyright
    }
}

public enum SheetError: Error {
    case outOfBounds(size: Size)
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

    public func images(target: ImagesTarget, configuration: ImagesConfiguration) throws {
        guard !configuration.components.isEmpty else {
            print("warning: configuration did not provide any components; no images generated")
            return
        }
        switch target {
        case let .png(url):
            let images = try ImageRenderer(
                configuration: configuration,
                destinationUrl: url,
                resourceUrl: bundle?.resourceURL
            )

            images.render()

        case .tts:
            fatalError("not implemented yet")
        }
    }

    public func document(target: DocumentTarget, configuration: DocumentConfiguration) throws {
        guard !configuration.layouts.isEmpty else {
            print("warning: configuration did not provide any layouts; document not generated")
            return
        }
        switch target {
        case let .proof(url):
            let pages = try arrange(using: configuration)

            let doc = try ProofRenderer(
                configuration: configuration,
                pages: pages,
                destinationUrl: url,
                resourceUrl: bundle?.resourceURL
            )
            
            try doc.render()

        case let .pdf(url):
            let tempLocationUrl = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("swift-boardgame-toolkit")
            try FileManager.default.createDirectory(
                at: tempLocationUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try document(target: .proof(at: tempLocationUrl), configuration: configuration)
            let proofUrl = tempLocationUrl.appendingPathComponent("proof")
            guard FileManager.default.fileExists(atPath: proofUrl.path) else {
                fatalError()
            }
            let doc = PDFRenderer(
                locationUrl: proofUrl,
                destinationUrl: url,
                paper: configuration.paper,
                meta: description
            )

            try doc.render()

            try FileManager.default.removeItem(at: tempLocationUrl)
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

        let layouts = configuration.layouts.splitBySize

        for layout in layouts {
            switch layout.method {
            case let .natural(order, gap):
                // natural layout is left-to-right
                let fronts = layout.components(orderedBy: order).map { component in
                    // note that every component is considered to be a front
                    // in this layout method
                    component.front(with: .front)
                }

                let frontPages = fronts.arrangedLeftToRight(
                    spacing: gap,
                    on: configuration.paper
                )

                pages.append(contentsOf: frontPages)
                
            case let .duplex(gap, guides):
                // similar to natural layout, except backs are reversed (i.e. right-to-left)
                // and separated to interleaved pages
                let fronts = layout.components.map { component in
                    component.front(with: guides)
                }

                let frontPages = fronts.arrangedLeftToRight(
                    spacing: gap,
                    on: configuration.paper
                )

                let backs = fronts.map { front in
                    front.back(with: guides)
                }

                let backPages = backs.arrangedLeftToRight(
                    spacing: gap,
                    on: configuration.paper,
                    reverse: true
                )

                let interleavedPages = frontPages.interleaved(with: backPages)

                if interleavedPages.count % 2 != 0 {
                    // duplex printing requires an even number of pages;
                    // for every page of fronts, a page of backs must follow
                    fatalError()
                }

                pages.append(contentsOf: interleavedPages)

            case let .fold(gap, gutter, guides):
                let fronts = layout.components.map { component in
                    component.front(with: guides)
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
                            ref.partition.real.bottom
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
                    spacing: gap,
                    on: Paper(boundedSize, Margin.zero)
                )

                for arrangedPage in upperPages {
                    let page = Page(size: configuration.paper.extent)
                    let b = arrangedPage.boundingBox
                    let foldOffset = b.height - ref.partition.real.bottom + gutter

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
                        let back = component.back(with: guides)
                        let turns: Layout.Turn?
                        if component.partition.full.extent.width > component.partition.full.extent.height {
                            // don't flip landscape-oriented components;
                            // these fold on left/right edges and end up in same orientation
                            turns = nil
                        } else {
                            // flip portrait-oriented components vertically so that
                            // they fold on the bottom edge
                            turns = .cw(.twice)
                        }
                        let bottom = foldOffset + gutter - ref.partition.real.bottom + b.height
                        let backVerticalOffset = bottom - component.portraitOrientedExtent.height - y
                        page.arrange(back, x: x, y: backVerticalOffset, rotatedBy: turns)
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
                                // note that every component is considered to be a front
                                // in this layout method
                                component.front(with: .front),
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
