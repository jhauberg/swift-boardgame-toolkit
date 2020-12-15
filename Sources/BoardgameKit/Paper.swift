import Foundation

public typealias Margin = Size

public struct Paper: Dimensioned {
    public let extent: Size
    public let margin: Margin

    let innerBounds: Size

    public init(_ size: Size, _ margin: Margin) {
        precondition(size.width > margin.width * 2)
        precondition(size.height > margin.height * 2)
        self.extent = size
        self.margin = margin
        self.innerBounds = Size(
            width: size.width - margin.width * 2,
            height: size.height - margin.height * 2
        )
    }

    public static let letter = Paper(
        Size(width: 8.5.inches,
             height: 11.inches),
        Margin.common
    )

    public static let a4 = Paper(
        Size(width: 21.centimeters,
             height: 29.7.centimeters),
        Margin.common
    )

    var portrait: Paper {
        self
    }

    var landscape: Paper {
        Paper(
            Size(width: extent.height,
                 height: extent.width),
            // note also flipping the vertical/horizontal margins
            Margin(width: margin.height,
                   height: margin.width)
        )
    }
}

extension Margin {
    static var common: Margin {
        Margin(width: 0.25.inches,
               height: 0.25.inches)
    }
}
