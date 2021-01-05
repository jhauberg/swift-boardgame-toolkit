import Foundation

public struct Layout {
    public enum Order {
        case interleavingBacks
        case frontsThenBacks
        case skippingBacks
    }

    let components: [Component]
    let method: Method

    public init(_ components: [Component], method: Method) {
        self.components = components
        self.method = method
    }

    private func components(orderedBy order: Order) -> [Component] {
        switch order {
        case .skippingBacks:
            return components
        case .frontsThenBacks:
            // would prefer using \.back key path here, but causes build error
            // see https://github.com/jhauberg/swift-boardgame-toolkit/issues/1
            return components + components.compactMap { $0.back }
        case .interleavingBacks:
            return components.interleaved(
                // would prefer using \.back key path here, but causes build error
                // see https://github.com/jhauberg/swift-boardgame-toolkit/issues/1
                with: components.compactMap { $0.back }
            )
        }
    }

    func pages(on paper: Paper) -> [Page] {
        switch method {
        case let .natural(order, gap):
            // natural layout is left-to-right
            let fronts = components(orderedBy: order).map { component in
                // note that every component is considered to be a front
                // in this layout method
                component.front(with: .front)
            }

            return fronts.arrangedLeftToRight(
                on: paper,
                spacing: gap
            )

        case let .duplex(gap, guides):
            // similar to natural layout, except backs are reversed (i.e. right-to-left)
            // and separated to interleaved pages
            let fronts = components.map { component in
                component.front(with: guides)
            }

            let frontPages = fronts.arrangedLeftToRight(
                on: paper,
                spacing: gap
            )

            let backs = fronts.map { front in
                front.back(with: guides)
            }

            let backPages = backs.arrangedLeftToRight(
                on: paper,
                spacing: gap,
                reverse: true
            )

            let interleavedPages = frontPages.interleaved(with: backPages)

            if interleavedPages.count % 2 != 0 {
                // duplex printing requires an even number of pages;
                // for every page of fronts, a page of backs must follow
                fatalError()
            }

            return interleavedPages

        case let .fold(gap, gutter, guides):
            let fronts = components.map { component in
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
                width: paper.innerBounds.width,
                height: (
                    ((paper.innerBounds.height / 2) - gutter) +
                        ref.parts.real.bottom
                )
            )

            // layout components in "pages" based on a marginless paper specification
            // exactly fitting the previously determined boundaries
            let upperPages = fronts.arrangedLeftToRight(
                on: Paper(boundedSize, Margin.zero),
                spacing: gap
            )

            var pages: [Page] = []

            for arrangedPage in upperPages {
                let page = Page(size: paper.extent)
                let b = arrangedPage.boundingBox
                let foldOffset = b.height - ref.parts.real.bottom + gutter

                page.fold(
                    // add a fold guide going across the entire paper, inside margins
                    x: .zero - ((paper.innerBounds.width / 2) - (b.width / 2)),
                    // note that Fold adjusts to center itself on the coordinate
                    // so we don't have to take that into account here
                    y: foldOffset,
                    distance: paper.innerBounds.width,
                    vertically: false
                )

                for case let .component(component, x, y, r) in arrangedPage.elements {
                    page.arrange(component, x: x, y: y, rotatedBy: r)
                    let back = component.back(with: guides)
                    let turns: Layout.Turn?
                    if component.parts.full.extent.width > component.parts.full.extent.height {
                        // don't flip landscape-oriented components;
                        // these fold on left/right edges and end up in same orientation
                        turns = nil
                    } else {
                        // flip portrait-oriented components vertically so that
                        // they fold on the bottom edge
                        turns = .cw(.twice)
                    }
                    let bottom = foldOffset + gutter - ref.parts.real.bottom + b.height
                    let backVerticalOffset = bottom - component.portraitOrientedExtent.height - y
                    page.arrange(back, x: x, y: backVerticalOffset, rotatedBy: turns)
                }

                pages.append(page)
            }

            return pages

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

            var fronts: [Component] = components(orderedBy: order).reversed()
            // reversed because we will be using popLast to empty the array
            // but still want the components in original order

            var pages: [Page] = []
            while !fronts.isEmpty { // repeat until we've arranged all components
                var page = Page(size: paper.extent, mode: .relativeToPageMargins)

                for arrangement in arrangements {
                    switch arrangement.kind {
                    case let .placement(rotation):
                        guard let component = fronts.popLast() else {
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
                            size: paper.extent,
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

            return pages
        }
    }
}

extension Layout {
    public init(_ components: ArraySlice<Component>, method: Method) {
        self.init(Array(components), method: method)
    }
}

extension Layout {
    public enum Method {
        /**
         Arrange components in order, allowing for single-sided printing (simplex printing).

         A gap can be specified to add spacing between each component horizontally and vertically.
         */
        case natural(
                orderedBy: Order = .frontsThenBacks,
                gap: Size = .zero
             )
        /**
         Arrange components such that fronts and backs go on odd and even pages, respectively,
         allowing for double-sided printing (duplex printing).

         A gap can be specified to add spacing between each component horizontally and vertically.

         # Printing

         For printers with a built-in duplexer (i.e. automatic double-sided printing),
         make sure that the print job is setup for either long-edge or short-edge binding
         for the paper orientation:

           * Portrait: Long-edge binding
           * Landscape: Short-edge binding

         For manual duplexing, may God be with you.
         */
        case duplex(
                gap: Size = .zero,
                guides: Guide.Distribution = .back
             )
        /**
         Arrange components such that fronts and backs go on the same page, mirrored from a
         folding line going through the middle of the page.

         A gap can be specified to add spacing between each component.

         The gutter is the distance from the fold, to the trim of each component;
         i.e. not including bleed.

         # Printing

         For best results and most accurate front/back alignment, make sure to fold so that
         the fold guide is visible on the crease/bulge of the paper.

         The fold can not be guaranteed to be perfectly centered in the middle of the page,
         so going by aligning the paper corners will not always be accurate.

         If your printer has large margins, consider reducing the bleed or folding gutter.
         */
        case fold(
                gap: Size = .zero,
                gutter: Distance = 6.millimeters,
                guides: Guide.Distribution = .back
             )
        /**
         Arrange components in order, at pre-defined placements and orientations on a page.

         This is useful when you have specific requirements for component arrangement.

         This method can be considered as a sort of _Bring Your Own Layout_ (BYOL) that allows for
         precise arrangement of components, cut and fold guides.
         You can think of it as putting "slots" on a page that components are put into.

         For example, this could be used to match the layout of a specific die-cutter,
         or to print on pre-cut/perforated paper.
         */
        case custom(
                orderedBy: Order,
                _ arrangements: [Arrangement]
             )
    }
}

extension Layout {
    public enum Turn {
        public enum Count: Int {
            case once = 1
            case twice = 2
            case thrice = 3
        }

        case cw(_ times: Count = .once)
        case ccw(_ times: Count = .once)

        var clockwiseOrientedRotation: Count {
            switch self {
            case let .cw(times):
                return times
            case let .ccw(times):
                switch times {
                case .once:
                    return .thrice
                case .twice:
                    return .twice
                case .thrice:
                    return .once
                }
            }
        }
    }

    enum ArrangementType {
        case placement(turned: Turn?)
        case pagebreak
        case cut(distance: Distance, vertically: Bool)
        case fold(distance: Distance, vertically: Bool)
    }

    public struct Arrangement {
        private(set) var offset: Size?

        let kind: ArrangementType

        init(offset: Size? = nil, kind: ArrangementType) {
            self.offset = offset
            self.kind = kind
        }

        public static func at(
            x: Units,
            y: Units,
            turned rotation: Turn? = nil
        ) -> Arrangement {
            Arrangement(offset: Size(width: x, height: y), kind: .placement(turned: rotation))
        }

        public static func cut(
            x: Units,
            y: Units,
            distance: Distance,
            vertically: Bool = false
        ) -> Arrangement {
            Arrangement(
                offset: Size(width: x, height: y),
                kind: .cut(distance: distance, vertically: vertically)
            )
        }

        public static func fold(
            x: Units,
            y: Units,
            distance: Distance,
            vertically: Bool = false
        ) -> Arrangement {
            Arrangement(
                offset: Size(width: x, height: y),
                kind: .fold(distance: distance, vertically: vertically)
            )
        }

        public static func pagebreak() -> Arrangement {
            Arrangement(kind: .pagebreak)
        }
    }
}

private extension Array where Element == Component {
    func arrangedLeftToRight(
        on paper: Paper,
        spacing: Size,
        reverse: Bool = false
    ) -> [Page] {
        precondition(spacing.width.value >= 0)
        precondition(spacing.height.value >= 0)

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
            guard component.portraitOrientedExtent.width <= paper.innerBounds.width,
                  component.portraitOrientedExtent.height <= paper.innerBounds.height else {
                // component does not fit on this paper
                fatalError()
            }
            let offset = Size(width: x, height: y)

            // temporarily store offset and component before laying out on page;
            // this is necessary to, at pagebreak, determine actual position on page
            // if we were always just laying out left-to-right, we would not have to do this
            // and could put it on page immediately; however, to determine the relative origin
            // for a layout flowing right-to-left, we have to first figure out just how wide
            // the relative boundary actually is
            content.append((offset, component))

            // increment positions
            x = offset.width + (component.portraitOrientedExtent.width + spacing.width)

            // note using 'x', not offset.width
            let nextRightEdge = x + component.portraitOrientedExtent.width
            if nextRightEdge > paper.innerBounds.width {
                // next line
                x = origin.width
                y = offset.height + (component.portraitOrientedExtent.height + spacing.height)
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
