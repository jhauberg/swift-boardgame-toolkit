import Foundation

public typealias Margin = Size

public struct Paper: Dimensioned {
    public let extent: Size
    public let margin: Margin

    var innerBounds: Size {
        Size(width: extent.width - margin.width * 2,
             height: extent.height - margin.height * 2)
    }

    // note that a paper must be initialized portrait-oriented;
    // landscape is produced by flipping the dimensions
    public init(_ size: Size, _ margin: Margin) {
        self.extent = size
        self.margin = margin
    }

    public static let letter = Paper(
        Size(width: 8.5.inches,
             height: 11.inches),
        Margin.common)

    public static let a4 = Paper(
        Size(width: 21.centimeters,
             height: 29.7.centimeters),
        Margin.common)

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
