import Foundation

public struct Layout {
    public enum Method {
        case natural(orderedBy: Order = .frontsThenBacks, Distance = .zero)
        /**
         Double-sided printing.

         A gap can be specified to add spacing between each card, both horizontally and vertically.
         */
        case duplex(gap: Distance = .zero)
        case fold(gap: Measurement<UnitLength> = .zero,
                  separation: Measurement<UnitLength> = 6.millimeters)

        case custom(orderedBy: Order, _ arrangements: [Arrangement])
    }

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
            Arrangement(offset: Size(width: x, height: y), kind: .cut(distance: distance, vertically: vertically))
        }

        public static func fold(
            x: Units,
            y: Units,
            distance: Distance,
            vertically: Bool = false
        ) -> Arrangement {
            Arrangement(offset: Size(width: x, height: y), kind: .fold(distance: distance, vertically: vertically))
        }

        public static func pagebreak() -> Arrangement {
            Arrangement(kind: .pagebreak)
        }
    }

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

    public init(_ components: ArraySlice<Component>, method: Method) {
        self.init(Array(components), method: method)
    }

    func components(orderedBy order: Order) -> [Component] {
        switch order {
        case .skippingBacks:
            return components
        case .frontsThenBacks:
            return components + components.compactMap(\.back)
        case .interleavingBacks:
            return components.interleaved(
                with: components.compactMap(\.back)
            )
        }
    }
}
