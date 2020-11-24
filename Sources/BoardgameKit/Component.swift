import Foundation

struct ComponentAttributes {
    var flip: Axis?
}

public struct ZonedArea {
    public let full: Area // largest area, before a cut; i.e. with bleed
    public let real: Area // final area after a cut; i.e. without bleed, but with trim
    public let safe: Area // smallest area, safely nested inside trim lines
}

// note that Component must be a class because it would otherwise
// contain a recursive value type; i.e. `back`
public final class Component: Dimensioned {
    private let trim: Distance
    private let bleed: Distance

    private(set) var extent: Size
    private(set) var elements: [Element] = []

    private(set) var attributes = ComponentAttributes()
    private(set) var back: Component?

    let zone: ZonedArea
    let portraitOrientedExtent: Size

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

        self.extent = size
        self.bleed = bleed
        self.trim = trim

        let bounds = Size(width: self.extent.width + bleed * 2,
                          height: self.extent.height + bleed * 2)

        portraitOrientedExtent = Size(width: min(bounds.width, bounds.height),
                                      height: max(bounds.width, bounds.height))

        let bledZone = Area(extent: bounds)
        let trimZone = Area(inset: bleed, in: bledZone)
        let safeZone = Area(inset: trim, in: trimZone)

        zone = ZonedArea(
            full: bledZone,
            real: trimZone,
            safe: safeZone)
    }

    /**
     Initializes a new boardgame component.

     - Parameters:
       - width: The physical width of the component.
       - height: The physical height of the component.
       - bleed: The distance extending outwards from the final, cut dimensions of the component.
       - trim: The distance extending inwards from the final, cut dimensions of the component.
       - form: The composition of elements that form the component.
       - zone: The zoned areas that make up the printed component.
     - Returns: A fully-formed boardgame component, ready to be arranged on a page.

     Detailed description goes here.
     */
    public convenience init(
        width: Distance,
        height: Distance,
        bleed: Distance = 0.125.inches,
        trim: Distance = 0.125.inches,
        @FeatureBuilder _ form: (_ zone: ZonedArea) -> Feature? = { _ in
            nil
        }
    ) {
        self.init(
            size: Size(width: width, height: height),
            bleed: bleed,
            trim: trim
        )
        if let elm =
            form(zone)
        {
            elements.append(
                contentsOf: elm.elements()
            )
        }
    }

    public func backside(@FeatureBuilder _ form: (_ zone: ZonedArea) -> Feature) -> Self {
        back = Component(
            width: extent.width,
            height: extent.height,
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
        guard component.extent.width == extent.width,
              component.extent.height == extent.height,
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
            Box(covering: zone.real)
                .border("crimson", width: borderWidth)
                // note use of outer-border here; if we instead covered the bleed using a
                // box with a wide border (inwards), then we could not cover the corner gap;
                // this would require an "inner-corner-radius", which is not a thing
                // we can solve this by exploiting box-shadow to add an "outer border" instead
                // note that this border is likely to go beyond the bounds of the component
                // but should just be clipped
                .outline("rgba(220, 20, 60, 0.25)", width: bleed + cornerRadius)
                .corners(radius: cornerRadius)
                .classed("do-not-print")
        elements.append(trimZone.element)
        if trim > .zero {
            let safeZone =
                Box(covering: zone.safe)
                    .border("royalblue", width: borderWidth, style: .dashed)
                    .corners(radius: cornerRadius)
                    .classed("do-not-print")
            elements.append(safeZone.element)
        }
        return self
    }
}
