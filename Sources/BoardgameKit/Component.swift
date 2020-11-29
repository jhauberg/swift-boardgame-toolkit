import Foundation

enum GuideStyle {
    case boxed(color: String)
    case extendedEdges(color: String)
    case crosshair(color: String)
}

public enum GuideDistribution {
    case front
    case back
    case frontAndBack
    case none
}

struct ComponentAttributes {
    var flip: Axis?
}

public struct ZonedArea {
    public let full: Area // largest area, before a cut; i.e. with bleed
    public let real: Area // final area after a cut; i.e. without bleed, but with trim
    public let safe: Area // smallest area, safely nested inside trim lines
}

public struct Component: Dimensioned {
    private let trim: Distance
    private let bleed: Distance

    private(set) var extent: Size
    private(set) var elements: [Element] = []

    private(set) var attributes = ComponentAttributes()
    // using a property wrapper to allow for having a recursive type reference here
    // see https://forums.swift.org/t/using-indirect-modifier-for-struct-properties/37600/18
    // without it, Component would have to be a class; and that comes with other problems;
    // for example, running any sheet output followed by a web output would cause
    // overlays to appear twice (as these would be added every time the component
    // was laid out on a page; which, in this case, happened twice)
    @Indirect private(set) var back: Component?

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

        let bounds = Size(width: self.extent.width + self.bleed * 2,
                          height: self.extent.height + self.bleed * 2)

        portraitOrientedExtent = Size(width: min(bounds.width, bounds.height),
                                      height: max(bounds.width, bounds.height))

        let bledZone = Area(extent: bounds)
        let trimZone = Area(inset: self.bleed, in: bledZone)
        let safeZone = Area(inset: self.trim, in: trimZone)

        zone = ZonedArea(
            full: bledZone,
            real: trimZone,
            safe: safeZone
        )
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
    public init(
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
        if let elm = form(zone) {
            elements.append(
                contentsOf: elm.elements
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
        var copy = self
        copy.attributes.flip = axis
        return copy
    }

    func withOverlays() -> Self {
        var copy = self
        let cornerRadius = 0.125.inches
        let borderWidth = 0.5.millimeters
        copy.elements.append(
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
                .element
        )
        if trim > .zero {
            copy.elements.append(
                Box(covering: zone.safe)
                    .border("royalblue", width: borderWidth, style: .dashed)
                    .corners(radius: cornerRadius)
                    .classed("do-not-print")
                    .element
            )
        }
        return copy
    }

    func withMarks(style: GuideStyle) -> Self {
        var copy = self

        // set the width of the guide
        // note that in order to make the best opportunity for accurate alignment in all scenarios,
        // this should correspond to the distance that most closely maps to a pixel in browser space
        // this is not always enough, and some browsers may still handle it differently
        // typically, the problem manifests itself as guides being ever-so slightly off
        // when components of different orientations are mixed in together
        // (because one of those orientations must be rotated,
        //  there's a good chance for rounding "errors" to occur)
        let trimWidth = 1.inches / 96
        let inset = (trimWidth / 2) * -1
        // solid style offers a more consistent look;
        // i.e. both dashed and dotted can look odd when overlapping
        let border: BorderStyle = .solid

        switch style {
        case let .boxed(color):
            copy.elements.append(
                Box(covering: Area(inset: inset, in: zone.real))
                    .border(color, width: trimWidth, style: border, edges: .all)
                    .classed("guide")
                    .element
            )
        case let .extendedEdges(color):
            let extent = 0.125.inches
            // set an additional distance to extend beyond the extent
            // note that this only prevents overlap into neighboring components if the arranged
            // components are of similar size and setup
            let reach = bleed
            copy.elements.append(
                Box(covering:
                    Area(top: inset,
                         left: inset - extent - reach,
                         right: inset - extent - reach,
                         bottom: inset,
                         in: zone.real))
                    .border(color, width: trimWidth, style: border, edges: [.top, .bottom])
                    .classed("guide")
                    .element
            )
            copy.elements.append(
                Box(covering:
                    Area(top: inset - extent - reach,
                         left: inset,
                         right: inset,
                         bottom: inset - extent - reach,
                         in: zone.real))
                    .border(color, width: trimWidth, style: border, edges: [.left, .right])
                    .classed("guide")
                    .element
            )
        case let .crosshair(color):
            let extent = 0.125.inches
            // set an additional distance to extend beyond the extent
            // note that this only prevents overlap into neighboring components if the arranged
            // components are of similar size and setup
            let reach = bleed
            // top-left
            copy.elements.append(
                Box(width: (extent * 2) + reach, height: extent)
                    .left(zone.real.left + inset - extent - reach)
                    .top(zone.real.top + inset)
                    .border(color, width: trimWidth, style: border, edges: [.top])
                    .classed("guide")
                    .element
            )
            copy.elements.append(
                Box(width: extent, height: (extent * 2) + reach)
                    .left(zone.real.left + inset)
                    .top(zone.real.top + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .left)
                    .classed("guide")
                    .element
            )
            // top-right
            copy.elements.append(
                Box(width: (extent * 2) + reach, height: extent)
                    .right(zone.real.right + inset - extent - reach)
                    .top(zone.real.top + inset)
                    .border(color, width: trimWidth, style: border, edges: [.top])
                    .classed("guide")
                    .element
            )
            copy.elements.append(
                Box(width: extent, height: (extent * 2) + reach)
                    .right(zone.real.right + inset)
                    .top(zone.real.top + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .right)
                    .classed("guide")
                    .element
            )
            // bottom-left
            copy.elements.append(
                Box(width: (extent * 2) + reach, height: extent)
                    .left(zone.real.left + inset - extent - reach)
                    .bottom(zone.real.bottom + inset)
                    .border(color, width: trimWidth, style: border, edges: [.bottom])
                    .classed("guide")
                    .element
            )
            copy.elements.append(
                Box(width: extent, height: (extent * 2) + reach)
                    .left(zone.real.left + inset)
                    .bottom(zone.real.bottom + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .left)
                    .classed("guide")
                    .element
            )
            // bottom-right
            copy.elements.append(
                Box(width: (extent * 2) + reach, height: extent)
                    .right(zone.real.right + inset - extent - reach)
                    .bottom(zone.real.bottom + inset)
                    .border(color, width: trimWidth, style: border, edges: [.bottom])
                    .classed("guide")
                    .element
            )
            copy.elements.append(
                Box(width: extent, height: (extent * 2) + reach)
                    .right(zone.real.right + inset)
                    .bottom(zone.real.bottom + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .right)
                    .classed("guide")
                    .element
            )
        }

        return copy
    }

    var empty: Component {
        Component(size: extent, bleed: bleed, trim: trim)
    }
}

@propertyWrapper
final class Indirect<Value> {
    init(wrappedValue initialValue: Value) {
        wrappedValue = initialValue
    }

    var wrappedValue: Value
}
