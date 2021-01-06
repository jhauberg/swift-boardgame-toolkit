import Foundation

struct TextAttributes {
    var size: Units = 12.points // approximately 0.1667 inches
    var family: String = "serif"
    var color: String? = "black"
    var horizontalAlignment: Text.HorizontalAlignment?
    var verticalAlignment: Text.VerticalAlignment?

    var backgroundColor: String?

    var rotation: RotationAttributes?
}

/**
 An element representing a block of text.

 By default, text blocks are sized to, but not confined by, the intrinsic size of the content.

 If you want to center a text, you must first confine it by each dimension you want to center on.
 */
public struct Text: Feature {
    public let form: Feature? = nil

    private var width: Distance?
    private var height: Distance?
    private var inset = Inset()
    private let content: String
    private var attributes = TextAttributes()
    private var htmlAttributes = HTMLAttributes()

    /**
     Initialize a new text with the given textual content.
     */
    public init(_ text: String) {
        content = text
    }

    public func font(size: Units, name: String) -> Self {
        precondition(size.value > 0)
        var copy = self
        copy.attributes.size = size
        copy.attributes.family = name
        return copy
    }

    public func color(_ foregroundColor: String) -> Self {
        var copy = self
        copy.attributes.color = foregroundColor
        return copy
    }

    public func background(_ color: String) -> Self {
        var copy = self
        copy.attributes.backgroundColor = color
        return copy
    }
}

extension Text {
    public enum HorizontalAlignment {
        case left
        case center
        case right
        case justify
    }

    public enum VerticalAlignment {
        case top
        case middle
        case bottom
    }

    public func align(horizontally: HorizontalAlignment) -> Self {
        var copy = self
        // note that alignment has no effect unless bounded horizontally (e.g. width is set)
        copy.attributes.horizontalAlignment = horizontally
        return copy
    }

    public func align(vertically: VerticalAlignment) -> Self {
        var copy = self
        // note that alignment has no effect unless bounded vertically (e.g. height is set)
        // we can't be sure height won't be set later, so no warning is emitted at this point
        copy.attributes.verticalAlignment = vertically
        return copy
    }
}

extension Text: Turnable {
    public func turn(_ angle: Angle, from anchor: Anchor = .center) -> Self {
        var copy = self
        copy.attributes.rotation = RotationAttributes(anchor: anchor, angle: angle)
        return copy
    }
}

extension Text: Insettable {
    public func top(_ inset: Distance) -> Self {
        var copy = self
        copy.inset.top = inset
        return copy
    }

    public func left(_ inset: Distance) -> Self {
        var copy = self
        copy.inset.left = inset
        return copy
    }

    public func right(_ inset: Distance) -> Self {
        var copy = self
        copy.inset.right = inset
        return copy
    }

    public func bottom(_ inset: Distance) -> Self {
        var copy = self
        copy.inset.bottom = inset
        return copy
    }
}

extension Text: Centerable {
    public func center(in area: Area, axis: Axis) -> Self {
        var copy = self
        if axis == .horizontal || axis == .both {
            guard let width = width else {
                preconditionFailure()
            }
            copy.inset.left = area.left + (area.extent.width / 2) - (width / 2)
        }
        if axis == .vertical || axis == .both {
            guard let height = height else {
                preconditionFailure()
            }
            copy.inset.top = area.top + (area.extent.height / 2) - (height / 2)
        }
        return copy
    }
}

extension Text: Confinable {
    public func width(_ width: Distance, height: Distance? = nil) -> Self {
        precondition(width.value > 0)
        var copy = self
        copy.width = width
        copy.height = height
        return copy
    }

    public func height(_ height: Distance) -> Self {
        precondition(height.value > 0)
        var copy = self
        copy.height = height
        return copy
    }
}

extension Text: ElementConvertible {
    var element: Element {
        .text(
            content,
            inset: inset,
            width: width,
            height: height,
            attributes: attributes,
            additional: htmlAttributes
        )
    }
}
