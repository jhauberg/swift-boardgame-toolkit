import Foundation

public typealias Margin = Size

public struct Paper {
    public let size: Size
    public let margin: Margin

    init(_ size: Size, _ margin: Margin) {
        self.size = size
        self.margin = margin
    }

    var bounds: Size {
        Size(width: size.width - margin.width * 2,
             height: size.height - margin.height * 2)
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
        Paper(Size(width: min(size.width, size.height),
                   height: max(size.width, size.height)),
              margin)
    }

    public var landscape: Paper {
        Paper(Size(width: max(size.width, size.height),
                   height: min(size.width, size.height)),
              margin)
    }
}
