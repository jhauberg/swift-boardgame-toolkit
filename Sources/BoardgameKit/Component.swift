import Foundation

struct ComponentAttributes {
    var flip: Axis?
}

public struct BuilderContext {
    public let full: Area // largest; i.e. with bleed
    public let real: Area // mid; i.e. without bleed, but with trim
    public let safe: Area // smallest; i.e. without bleed and trim
}

// note that Component must be a class because it would otherwise
// contain a recursive value type; i.e. `back`
public final class Component {
    private let size: Size
    private let trim: Distance
    private let bleed: Distance

    let full: Area
    let innerRect: Area
    let safeRect: Area

    let portraitOrientedBounds: Size

    private(set) var elements: [Element] = []

    private(set) var attributes = ComponentAttributes()
    private(set) var back: Component?

    /**
     Initializes a new boardgame component.

     - Parameters:
       - size: The physical dimensions of the component.
       - bleed: The distance extending outwards from the final, cut dimensions of the component.
       - trim: The distance extending inwards from the final, cut dimensions of the component.
     - Returns: A fully-formed boardgame component, ready to be laid out on a page.

     For internal use only, at the moment.
     */
    init(
        size: Size,
        bleed: Distance,
        trim: Distance
    ) {
        precondition(size.width.value > 0)
        precondition(size.height.value > 0)
        precondition(bleed.value >= 0)
        precondition(trim.value >= 0)

        self.size = size
        self.bleed = bleed
        self.trim = trim

        let bounds = Size(width: self.size.width + bleed * 2,
                          height: self.size.height + bleed * 2)

        portraitOrientedBounds = Size(width: min(bounds.width, bounds.height),
                                      height: max(bounds.width, bounds.height))

        full = Area(extent: bounds)
        innerRect = Area(inset: bleed, in: full)
        safeRect = Area(inset: trim, in: innerRect)
    }

    /**
     Initializes a new boardgame component.

     - Parameters:
       - width: The physical width of the component.
       - height: The physical height of the component.
       - bleed: The distance extending outwards from the final, cut dimensions of the component.
       - trim: The distance extending inwards from the final, cut dimensions of the component.
       - form: The composition of elements that form the component.
       - context: ...
     - Returns: A fully-formed boardgame component, ready to be laid out on a page.

     Detailed description goes here.
     */
    public convenience init(
        width: Distance,
        height: Distance,
        bleed: Distance = 0.125.inches,
        trim: Distance = 0.125.inches,
        @FeatureBuilder _ form: (_ context: BuilderContext) -> Feature? = { _ in
            nil
        }
    ) {
        self.init(
            size: Size(width: width, height: height),
            bleed: bleed,
            trim: trim
        )
        if let elm =
            form(BuilderContext(full: full,
                                real: innerRect,
                                safe: safeRect))
        {
            elements.append(
                contentsOf: elm.elements()
            )
        }
    }

    public func backside(@FeatureBuilder _ form: (_ context: BuilderContext) -> Feature) -> Self {
        back = Component(
            width: size.width,
            height: size.height,
            bleed: bleed,
            trim: trim,
            form
        )
        return self
    }

    public func back(using component: Component) -> Self {
        guard component.back == nil else {
            print("warning: using frontside component as backside; back not set")
            return self
        }
        guard component.size.width == size.width,
              component.size.height == size.height,
              component.bleed == bleed,
              trim == trim
        else {
            print("warning: backside dimensions differ from frontside; back not set")
            return self
        }
        back = component
        return self
    }

    public func flipped(axis: Axis = .both) -> Self {
        attributes.flip = axis
        return self
    }

    func withOverlays() -> Self {
        let cornerRadius = 0.125.inches
        let borderWidth = 0.5.millimeters
        let trimZone =
            Box(covering: innerRect)
                .border("crimson", width: borderWidth)
                // note use of outer-border here; if we instead covered the bleed using a
                // box with a wide border (inwards), then we could not cover the corner gap;
                // this would require an "inner-corner-radius", which is not a thing
                // we can solve this by exploiting box-shadow to add an "outer border" instead
                // note that this border is likely to go beyond the bounds of the component
                // but should just be clipped
                .outline("rgba(220, 20, 60, 0.25)", width: innerRect.left + cornerRadius)
                .corners(radius: cornerRadius)
                .classed("do-not-print")
        elements.append(trimZone.element)
        if safeRect.left > 0.inches {
            let safeZone =
                Box(covering: safeRect)
                    .border("royalblue", width: borderWidth, style: "dashed")
                    .corners(radius: cornerRadius)
                    .classed("do-not-print")
            elements.append(safeZone.element)
        }
        return self
    }
}
