import Foundation

/**
 An inline image element.
 */
public struct Icon {
    private let path: String
    private var scale: Double = 1

    public init(_ path: String) {
        self.path = path
    }

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
