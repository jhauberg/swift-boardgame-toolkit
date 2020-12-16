import Foundation

struct ImageAttributes {
    var mode: Image.ScaleMode?
    var rotation: RotationAttributes?
}

public struct Image: Feature {
    public let form: Feature? = nil

    private var width: Distance?
    private var height: Distance?
    private var inset = Inset()
    private let path: String
    private var attributes = ImageAttributes()
    private var htmlAttributes = HTMLAttributes()

    public init(_ path: String) {
        self.path = path
    }
}

extension Image {
    public enum ScaleMode {
        case contain
        case cover
        case fill
    }

    public func scale(_ mode: ScaleMode) -> Self {
        var copy = self
        copy.attributes.mode = mode
        return copy
    }
}

extension Image: Turnable {
    public func turn(_ angle: Angle, from anchor: Anchor = .center) -> Self {
        var copy = self
        copy.attributes.rotation = RotationAttributes(anchor: anchor, angle: angle)
        return copy
    }
}

extension Image: Centerable {
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

extension Image: Confinable {
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

extension Image: Insettable {
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

extension Image: ElementConvertible {
    var element: Element {
        .image(
            path,
            inset: inset,
            width: width,
            height: height,
            attributes: attributes,
            additional: htmlAttributes
        )
    }
}
