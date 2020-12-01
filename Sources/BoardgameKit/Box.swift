import Foundation

struct BoxAttributes {
    var backgroundColor: String?
    var borderWidth: Distance?
    var borderColor: String?
    var borderStyle: Box.BorderStyle?
    var borderRadius: Distance?
    var borderEdges: Box.Border?

    var rotation: RotationAttributes?

    var outerBorderColor: String?
    var outerBorderWidth: Distance?
}

public struct Box: Feature, Dimensioned {
    public let form: Feature? = nil

    private(set) var extent: Size

    private var inset = Inset()
    private var attributes = BoxAttributes()
    private var htmlAttributes = HTMLAttributes()

    public init(width: Distance, height: Distance) {
        precondition(width.value > 0)
        precondition(height.value > 0)
        extent = Size(width: width, height: height)
    }

    public init(extent: Size) {
        self.init(width: extent.width,
                  height: extent.height)
    }

    public init(covering area: Area) {
        self.init(extent: area.extent)
        // note the intentional "reversed" ordering of properties here
        // an area provides insets for _all_ its edges, but a box wants only two;
        // one horizontal and one vertical (i.e. _either_ top or bottom; never both)
        // at this point, we can't know which edges to use, so we just try them all
        // however, we prefer to use top/left for positioning, so applying those lastly
        // lets us nil out bottom/right and end up with only top/left
        // note that this _only_ works because a box has a non-optional boundary (e.g. width/height)
        // if it did not, this approach would not be valid
        inset.bottom = area.bottom
        inset.right = area.right
        inset.left = area.left
        inset.top = area.top
    }

    public func corners(radius: Units) -> Self {
        var copy = self
        copy.attributes.borderRadius = radius
        return copy
    }

    public func background(_ color: String) -> Self {
        if let backgroundColor = attributes.backgroundColor {
            print(
                "warning: background color \"\(backgroundColor)\" already set; overridden by \"\(color)\""
            )
        }
        var copy = self
        copy.attributes.backgroundColor = color
        return copy
    }

    public func outline(
        _ color: String,
        width: Distance = 1.millimeters
    ) -> Self {
        var copy = self
        copy.attributes.outerBorderColor = color
        copy.attributes.outerBorderWidth = width
        return copy
    }

    func classed(_ className: String) -> Self {
        var copy = self
        if !copy.htmlAttributes.classes.contains(className) {
            copy.htmlAttributes.classes.append(className)
        }
        return copy
    }
}

extension Box {
    public enum BorderStyle {
        case solid
        case dotted
        case dashed
        case groove
        case double
    }

    public struct Border: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let top = Border(rawValue: 1 << 0)
        public static let left = Border(rawValue: 1 << 1)
        public static let right = Border(rawValue: 1 << 2)
        public static let bottom = Border(rawValue: 1 << 3)

        public static let all: Border = [.top, .right, .bottom, .left]
    }
    
    // note that borders always go _inside_ the box, as all features have `box-sizing: border-box`
    public func border(
        _ color: String,
        width: Distance = 1.millimeters,
        style: BorderStyle = .solid,
        edges: Border = .all
    ) -> Self {
        var copy = self
        copy.attributes.borderColor = color
        copy.attributes.borderStyle = style
        copy.attributes.borderWidth = width
        copy.attributes.borderEdges = edges
        return copy
    }
}

extension Box: Turnable {
    public func turn(_ angle: Angle, from anchor: Anchor = .center) -> Self {
        var copy = self
        copy.attributes.rotation = RotationAttributes(anchor: anchor, angle: angle)
        return copy
    }
}

extension Box: Insettable {
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

extension Box: Centerable {
    public func center(in area: Area, axis: Axis) -> Self {
        var copy = self
        if axis == .horizontal || axis == .both {
            copy.inset.left = area.left + (area.extent.width / 2) - (extent.width / 2)
        }
        if axis == .vertical || axis == .both {
            copy.inset.top = area.top + (area.extent.height / 2) - (extent.height / 2)
        }
        return copy
    }
}

extension Box: Confinable {
    func width(_ width: Distance, height: Distance? = nil) -> Self {
        var copy = self
        copy.extent = Size(width: width, height: height ?? extent.height)
        return copy
    }

    func height(_ height: Distance) -> Self {
        var copy = self
        copy.extent = Size(width: extent.width, height: height)
        return copy
    }
}

extension Box: ElementConvertible {
    var element: Element {
        .rect(
            inset: inset,
            bounds: extent,
            attributes: attributes,
            additional: htmlAttributes
        )
    }
}
