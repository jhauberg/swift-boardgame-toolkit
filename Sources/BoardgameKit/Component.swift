import Foundation

struct ComponentAttributes {
    var flip: Axis?
}

/**
 A discrete piece to a boardgame.

 A `Component` is any physical piece (component) of your boardgame; it could be a card, a token
 or a page of rules. Anything that would eventually be laid out on a page for printing.

 ## Features

 Components are made up of visual elements (features), and are formed at initialization.
 Once formed, additional features can no longer be added.

 ### Areas

 During initialization, a scope is provided to form the component. This scope includes an implicit
 reference to the 3 distinct areas of the component, as defined by its `bleed` and `trim`.
 These are, 1) the full area of the component, including bleed, 2) the final, _real_ area that
 remain after having been cut, and finally, 3) the "safe" area, which is always less than,
 or equal to, the final area- ensuring content placed here being _inside_ the trim.

 These areas can be used as guides to layout and position features.

 ### Order

 When forming components, the order of features matter. Here, the Painter's Algorithm applies.
 That is, features added earlier are obscured by those added later.

 For example, the following component is formed with 2 features,
 however, only a black box would show:

     Component(width: 2.5.inches, height: 3.5.inches) {
        Text("My Card")
            .color("white")
        Box(covering: $0.full)
            .background("black")
     }

 Swapping the order of the features would make white text appear on top of the black box.
 */
public struct Component: Dimensioned {
    private let trim: Distance
    private let bleed: Distance

    private(set) var extent: Size
    private(set) var elements: [Element] = []

    private var marks: GuideStyle? = .crosshair(color: "grey")

    private(set) var attributes = ComponentAttributes()
    // using a property wrapper to allow for having a recursive type reference here
    // see https://forums.swift.org/t/using-indirect-modifier-for-struct-properties/37600/18
    // without it, Component would have to be a class; and that comes with other problems;
    // for example, running any sheet output followed by a web output would cause
    // overlays to appear twice (as these would be added every time the component
    // was laid out on a page; which, in this case, happened twice)
    @Indirect private(set) var back: Component?

    let parts: Partition
    /**
     The physical dimensions of this component when oriented such that its longest edge goes
     vertically.

     For example, a component that is wider than it is tall, would have its dimensions flipped
     when using this property. For a component that is taller than it is wide, this property
     would be equal to `extent`.
     */
    let portraitOrientedExtent: Size

    /**
     Initializes a new boardgame component.

     - Parameters:
       - size: The physical dimensions of the component.
       - bleed: The distance extending outwards from the final, cut dimensions of the component.
       - trim: The distance extending inwards from the final, cut dimensions of the component.
     - Returns: A fully-formed boardgame component, ready to be laid out on a page.
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

        let bleedZone = Area(extent: bounds)
        let trimZone = Area(inset: self.bleed, in: bleedZone)
        let safeZone = Area(inset: self.trim, in: trimZone)

        parts = Partition(
            full: bleedZone,
            real: trimZone,
            safe: safeZone
        )
    }

    /**
     Initializes a new and discrete boardgame component.

     - Parameters:
       - width: The physical width of the component.
       - height: The physical height of the component.
       - bleed: The distance extending outwards from the final, cut dimensions of the component.
       - trim: The distance extending inwards from the final, cut dimensions of the component.
       - form: The composition of elements that form the component.
       - parts: The distinct areas that make up the component.
     - Returns: A discrete component, ready to be arranged on a page.
     */
    public init(
        width: Distance,
        height: Distance,
        bleed: Distance = 0.125.inches,
        trim: Distance = 0.125.inches,
        @FeatureBuilder _ form: (_ parts: Partition) -> Feature? = { _ in
            nil
        }
    ) {
        self.init(
            size: Size(width: width, height: height),
            bleed: bleed,
            trim: trim
        )
        if let elm = form(parts) {
            elements.append(
                contentsOf: elm.elements
            )
        }
    }

    /**
     Form a component to represent the backside to this frontside.

     - Parameters:
       - form: The composition of elements that form the component.
       - area: The distinct areas that make up the component.
     */
    public func backside(@FeatureBuilder _ form: (_ parts: Partition) -> Feature) -> Self {
        back = Component(
            width: extent.width,
            height: extent.height,
            bleed: bleed,
            trim: trim,
            form
        )
        return self
    }

    /**
     Set the component that represents the backside to this frontside.
     */
    public func backside(using component: Component) -> Self {
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

    /**
     Specify the style of cut guides for this component.

     The default style for any component is corner crosshairs. A `nil` style indicates that
     this component should never have any cut guides applied to it.

     Note that any associated backside does not inherit the style specified here.
     */
    public func guides(_ style: GuideStyle?) -> Self {
        var copy = self
        copy.marks = style
        return copy
    }

    func with(feature: Feature) -> Self {
        var copy = self
        copy.elements.append(
            contentsOf: feature.elements
        )
        return copy
    }

    func with(@FeatureBuilder _ form: (_ parts: Partition) -> Feature) -> Self {
        return with(feature: form(parts))
    }

    /**
     Returns the backside of this component for proofing.
     */
    func back(with guides: GuideDistribution) -> Component {
        // an "empty" back should never show overlays to indicate that it is, indeed,
        // an empty back; however, it _should_ be able to show cut guides
        let backside = back?.addingOverlays() ?? removingElements
        guard let marks = marks, guides != .front else {
            return backside
        }
        return backside.addingMarks(style: marks)
    }

    /**
     Returns the frontside of this component for proofing.
     */
    func front(with guides: GuideDistribution) -> Component {
        let frontside = addingOverlays()
        guard let marks = marks, guides != .back else {
            return frontside
        }
        return frontside.addingMarks(style: marks)
    }

    /**
     Returns an empty component, identical to this component in both dimensions and partitioning.
     */
    private var removingElements: Component {
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

extension Component {
    public struct Partition {
        public let full: Area // largest area, before a cut; i.e. with bleed
        public let real: Area // final area after a cut; i.e. without bleed, but with trim
        public let safe: Area // smallest area, safely nested inside trim lines

        init(full: Area, real: Area, safe: Area) {
            self.full = full
            self.real = real
            self.safe = safe
        }
    }
}

extension Component {
    private func addingOverlays() -> Self {
        let cornerRadius = 0.125.inches
        let borderWidth = 0.5.millimeters
        return with { parts in
            Box(covering: parts.real)
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

            if trim > .zero {
                Box(covering: parts.safe)
                    .border("royalblue", width: borderWidth, style: .dashed)
                    .corners(radius: cornerRadius)
                    .classed("do-not-print")
            }
        }
    }
}

extension Component {
    public enum GuideDistribution {
        case front
        case back
        case frontAndBack
    }

    public enum GuideStyle {
        case boxed(color: String)
        case extendedEdges(color: String)
        case crosshair(color: String)
    }

    private func addingMarks(style: GuideStyle) -> Self {
        // set the width of the guide
        // note that in order to make the best opportunity for accurate alignment in all scenarios,
        // this should correspond to the distance that most closely maps to a pixel in browser space
        // this is not always enough, and some browsers may still handle it differently
        // typically, the problem manifests itself as guides being ever-so slightly off
        // when components of different orientations are mixed in together
        // (because one of those orientations must be rotated,
        //  there's a good chance for rounding "errors" to occur)
        let trimWidth = 1.inches / 96
        // inset outwards from outer edge of trim line (half on the inside, half on the outside)
        let inset = (trimWidth / 2) * -1
        // solid style offers a more consistent look;
        // i.e. both dashed and dotted can look odd when overlapping
        let border: Box.BorderStyle = .solid

        switch style {
        case let .boxed(color):
            return with { parts in
                Box(covering: Area(inset: inset, in: parts.real))
                    .border(color, width: trimWidth, style: border, edges: .all)
                    .classed("guide")
            }
        case let .extendedEdges(color):
            let extent = trimWidth * 5
            // set an additional distance to extend beyond the extent
            // note that this only prevents overlap into neighboring components if the arranged
            // components are of similar size and setup
            let reach = bleed
            return with { parts in
                Box(covering:
                        Area(top: inset,
                             left: inset - extent - reach,
                             right: inset - extent - reach,
                             bottom: inset,
                             in: parts.real))
                    .border(color, width: trimWidth, style: border, edges: [.top, .bottom])
                    .classed("guide")
                Box(covering:
                        Area(top: inset - extent - reach,
                             left: inset,
                             right: inset,
                             bottom: inset - extent - reach,
                             in: parts.real))
                    .border(color, width: trimWidth, style: border, edges: [.left, .right])
                    .classed("guide")
            }
        case let .crosshair(color):
            let extent = trimWidth * 5
            // set an additional distance to extend beyond the extent
            // note that this only prevents overlap into neighboring components if the arranged
            // components are of similar size and setup
            let reach = bleed
            return with { parts in
                // top-left
                Box(width: (extent * 2) + reach, height: extent)
                    .left(parts.real.left + inset - extent - reach)
                    .top(parts.real.top + inset)
                    .border(color, width: trimWidth, style: border, edges: [.top])
                    .classed("guide")
                Box(width: extent, height: (extent * 2) + reach)
                    .left(parts.real.left + inset)
                    .top(parts.real.top + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .left)
                    .classed("guide")

                // top-right
                Box(width: (extent * 2) + reach, height: extent)
                    .right(parts.real.right + inset - extent - reach)
                    .top(parts.real.top + inset)
                    .border(color, width: trimWidth, style: border, edges: [.top])
                    .classed("guide")
                Box(width: extent, height: (extent * 2) + reach)
                    .right(parts.real.right + inset)
                    .top(parts.real.top + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .right)
                    .classed("guide")

                // bottom-left
                Box(width: (extent * 2) + reach, height: extent)
                    .left(parts.real.left + inset - extent - reach)
                    .bottom(parts.real.bottom + inset)
                    .border(color, width: trimWidth, style: border, edges: [.bottom])
                    .classed("guide")
                Box(width: extent, height: (extent * 2) + reach)
                    .left(parts.real.left + inset)
                    .bottom(parts.real.bottom + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .left)
                    .classed("guide")

                // bottom-right
                Box(width: (extent * 2) + reach, height: extent)
                    .right(parts.real.right + inset - extent - reach)
                    .bottom(parts.real.bottom + inset)
                    .border(color, width: trimWidth, style: border, edges: [.bottom])
                    .classed("guide")
                Box(width: extent, height: (extent * 2) + reach)
                    .right(parts.real.right + inset)
                    .bottom(parts.real.bottom + inset - extent - reach)
                    .border(color, width: trimWidth, style: border, edges: .right)
                    .classed("guide")
            }
        }
    }
}
