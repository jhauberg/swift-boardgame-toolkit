import Foundation

public struct Area: Dimensioned {
    public let extent: Size

    public static let empty = Area(extent: .zero)

    public private(set) var top: Distance
    public private(set) var left: Distance
    public private(set) var right: Distance
    public private(set) var bottom: Distance

    public init(extent: Size) {
        let zero = 0.inches
        top = zero
        left = zero
        right = zero
        bottom = zero
        self.extent = extent
    }

    public init(
        top: Distance? = nil,
        left: Distance? = nil,
        right: Distance? = nil,
        bottom: Distance? = nil,
        in area: Area
    ) {
        let zero = 0.inches
        // default each edge if needed
        self.top = top ?? zero
        self.left = left ?? zero
        self.right = right ?? zero
        self.bottom = bottom ?? zero
        // determine extents before applying parent insets
        extent = Size(
            width: area.extent.width - (self.left + self.right),
            height: area.extent.height - (self.top + self.bottom)
        )
        // apply parent insets
        self.top = self.top + area.top
        self.left = self.left + area.left
        self.right = self.right + area.right
        self.bottom = self.bottom + area.bottom
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
}
