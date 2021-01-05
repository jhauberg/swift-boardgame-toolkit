import Foundation

/**
 The measurement of a surface on a rectangular shape.
 */
public struct Area: Dimensioned {
    public let extent: Size

    public static let empty = Area(extent: .zero)

    // inset from respective edges of any parent area
    private var inset = Inset(allowingOppositeInsets: true)

    public var top: Distance {
        inset.top ?? .zero
    }

    public var left: Distance {
        inset.left ?? .zero
    }

    public var right: Distance {
        inset.right ?? .zero
    }

    public var bottom: Distance {
        inset.bottom ?? .zero
    }

    public init(extent: Size) {
        self.extent = extent
    }

    public init(
        top: Distance? = nil,
        left: Distance? = nil,
        right: Distance? = nil,
        bottom: Distance? = nil,
        in area: Area
    ) {
        let t = top ?? .zero
        let l = left ?? .zero
        let r = right ?? .zero
        let b = bottom ?? .zero
        // determine extents before applying parent insets
        extent = Size(
            width: area.extent.width - (l + r),
            height: area.extent.height - (t + b)
        )
        precondition(extent.width.value >= 0)
        precondition(extent.height.value >= 0)
        // apply insets + parent insets
        inset.top = t + area.top
        inset.left = l + area.left
        inset.right = r + area.right
        inset.bottom = b + area.bottom
    }

    public init(
        inset: Distance,
        in area: Area
    ) {
        self.init(
            top: inset,
            left: inset,
            right: inset,
            bottom: inset,
            in: area
        )
    }

    public func inset(
        top: Distance,
        left: Distance? = nil,
        right: Distance? = nil,
        bottom: Distance? = nil
    ) -> Area {
        Area(top: top, left: left, right: right, bottom: bottom, in: self)
    }

    public func inset(
        top: Distance? = nil,
        left: Distance,
        right: Distance? = nil,
        bottom: Distance? = nil
    ) -> Area {
        Area(top: top, left: left, right: right, bottom: bottom, in: self)
    }

    public func inset(
        top: Distance? = nil,
        left: Distance? = nil,
        right: Distance,
        bottom: Distance? = nil
    ) -> Area {
        Area(top: top, left: left, right: right, bottom: bottom, in: self)
    }

    public func inset(
        top: Distance? = nil,
        left: Distance? = nil,
        right: Distance? = nil,
        bottom: Distance
    ) -> Area {
        Area(top: top, left: left, right: right, bottom: bottom, in: self)
    }
}
