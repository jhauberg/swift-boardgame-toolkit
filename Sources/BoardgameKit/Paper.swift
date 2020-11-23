import Foundation

public typealias Margin = Size

public struct Paper: Dimensioned {
    public let extent: Size
    public let margin: Margin

    init(_ size: Size, _ margin: Margin) {
        self.extent = size
        self.margin = margin
    }

    var innerBounds: Size {
        Size(width: extent.width - margin.width * 2,
             height: extent.height - margin.height * 2)
    }

    public static let letter = Paper(Size(width: 21.59.centimeters,
                                          height: 27.94.centimeters),
                                     Margin(width: 9.75.millimeters,
                                            height: 9.75.millimeters))

    public static let a4 = Paper(Size(width: 21.centimeters,
                                      height: 29.7.centimeters),
                                 Margin(width: 8.millimeters,
                                        height: 8.millimeters))

    public var portrait: Paper {
        Paper(Size(width: min(extent.width, extent.height),
                   height: max(extent.width, extent.height)),
              margin)
    }

    public var landscape: Paper {
        Paper(Size(width: max(extent.width, extent.height),
                   height: min(extent.width, extent.height)),
              margin)
    }
}
