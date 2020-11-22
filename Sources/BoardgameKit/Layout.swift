import Foundation

public struct Layout {
    public enum Method {
        case natural(orderedBy: Order = .frontsThenBacks, Distance = 0.inches)
        /**
         Double-sided printing.

         A gap can be specified to add spacing between each card, both horizontally and vertically.
         */
        case duplex(gap: Distance = 0.inches)
        case fold(
            gap: Measurement<UnitLength> = 0.inches,
            separation: Measurement<UnitLength> = 6.millimeters
        )

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
        case placement(breaks: Bool, turned: Turn?)
        case cut(distance: Measurement<UnitLength>, vertically: Bool)
        case fold(distance: Measurement<UnitLength>, vertically: Bool)
    }

    public struct Arrangement {
        private let x: Measurement<UnitLength>
        private let y: Measurement<UnitLength>

        let kind: ArrangementType

        public static func at(
            x: Measurement<UnitLength>,
            y: Measurement<UnitLength>,
            turned rotation: Turn? = nil,
            breaks: Bool = false
        ) -> Arrangement {
            Arrangement(x: x, y: y, kind: .placement(breaks: breaks, turned: rotation))
        }

        public static func cut(
            x: Measurement<UnitLength>,
            y: Measurement<UnitLength>,
            distance: Measurement<UnitLength>,
            vertically: Bool = false
        ) -> Arrangement {
            Arrangement(x: x, y: y, kind: .cut(distance: distance, vertically: vertically))
        }

        public static func fold(
            x: Measurement<UnitLength>,
            y: Measurement<UnitLength>,
            distance: Measurement<UnitLength>,
            vertically: Bool = false
        ) -> Arrangement {
            Arrangement(x: x, y: y, kind: .fold(distance: distance, vertically: vertically))
        }

        var offset: Size {
            Size(width: x, height: y)
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
