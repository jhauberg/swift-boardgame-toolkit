import Foundation

/**
 An inline image element.
 */
public struct Icon {
    private let path: String
    private var scale: Double = 1

    /**
     Initialize a new icon with the given resource path.

     If the path is relative, it must be relative against the resource bundle.

     Icons are always sized to the intrinsic size of the image resource and scale automatically
     with the text they occur within.
     */
    public init(_ path: String) {
        self.path = path
    }

    /**
     Set the scaling.

     An icon is always sized relative to the text it occurs within.

     This means that a scale of `1` will size the icon to match the text, while a scale of `2`
     will size the icon to be twice as large as the text.

     Similarly, a scale of `0.5` makes the icon become half the size of the text.

     Default is `1`.
     */
    public func scaled(_ scale: Double) -> Self {
        precondition(scale >= 0)
        var copy = self
        copy.scale = scale
        return copy
    }
}

extension Icon: HTMLConvertible {
    var html: String {
        "<img src=\"\(path)\" style=\"height: \(scale)em;\">"
    }
}

extension Icon: CustomStringConvertible {
    public var description: String {
        html
    }
}
