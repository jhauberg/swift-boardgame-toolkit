import Foundation

extension Element: HTMLConvertible {
    var html: String {
        switch self {
        // features
        case .rect:
            return htmlrect(self)
        case .text:
            return htmltext(self)
        case .image:
            return htmlimage(self)
        case .freeform:
            return htmlblock(self)
        // composites
        case .component:
            return htmlcomponent(self)
        case .document:
            return htmldoc(self)
        case .page:
            return htmlpage(self)
        }
    }
}

private func htmlrect(_ element: Element) -> String {
    guard case let .rect(inset, bounds, attributes, additional) = element else {
        preconditionFailure()
    }
    let classes = ["component-element"] + additional.classes
    var style = Style()
    style.set("width", value: bounds.width)
    style.set("height", value: bounds.height)
    if let top = inset.top {
        style.set("top", value: top)
    }
    if let left = inset.left {
        style.set("left", value: left)
    }
    if let right = inset.right {
        style.set("right", value: right)
    }
    if let bottom = inset.bottom {
        style.set("bottom", value: bottom)
    }
    if let backgroundColor = attributes.backgroundColor {
        style.set("background-color", value: backgroundColor)
    }
    if let borderRadius = attributes.borderRadius {
        style.set("border-radius", value: borderRadius)
    }
    if let borderColor = attributes.borderColor,
       let borderStyle = attributes.borderStyle,
       let borderWidth = attributes.borderWidth,
       let borderEdges = attributes.borderEdges
    {
        let lineStyle: String
        switch borderStyle {
        case .solid:
            lineStyle = "solid"
        case .dotted:
            lineStyle = "dotted"
        case .dashed:
            lineStyle = "dashed"
        case .groove:
            lineStyle = "groove"
        case .double:
            lineStyle = "double"
        }
        if borderEdges == .all {
            style.set("border", value: borderWidth)
            style.append("border", value: lineStyle)
            style.append("border", value: borderColor)
        } else {
            if borderEdges.contains(.top) {
                style.set("border-top", value: borderWidth)
                style.append("border-top", value: lineStyle)
                style.append("border-top", value: borderColor)
            }
            if borderEdges.contains(.right) {
                style.set("border-right", value: borderWidth)
                style.append("border-right", value: lineStyle)
                style.append("border-right", value: borderColor)
            }
            if borderEdges.contains(.bottom) {
                style.set("border-bottom", value: borderWidth)
                style.append("border-bottom", value: lineStyle)
                style.append("border-bottom", value: borderColor)
            }
            if borderEdges.contains(.left) {
                style.set("border-left", value: borderWidth)
                style.append("border-left", value: lineStyle)
                style.append("border-left", value: borderColor)
            }
        }
    }
    if let outerBorderColor = attributes.outerBorderColor,
       let outerBorderWidth = attributes.outerBorderWidth
    {
        style.set("box-shadow", value: "0 0 0")
        style.append("box-shadow", value: outerBorderWidth)
        style.append("box-shadow", value: outerBorderColor)
    }
    if let rotation = attributes.rotation {
        style.set(
            "transform-origin",
            value: rotation.anchor.css
        )
        style.set(
            "transform",
            value: "rotate(\(rotation.angle.css))"
        )
    }
    return """
    <div\
     class=\"\(classes.joined(separator: " "))\"\
     style=\"\(style.css)\">\
    </div>\n
    """
}

private func htmltext(_ element: Element) -> String {
    guard case let .text(content, inset, width, height, attributes, additional) = element else {
        preconditionFailure()
    }
    let classes = ["component-element"] + additional.classes
    var style = Style()
    if let w = width {
        style.set("width", value: w)
    }
    if let h = height {
        style.set("height", value: h)
    }
    if width != nil || height != nil {
        style.set("overflow", value: "hidden")
    }
    if let top = inset.top {
        style.set("top", value: top)
    }
    if let left = inset.left {
        style.set("left", value: left)
    }
    if let right = inset.right {
        style.set("right", value: right)
    }
    if let bottom = inset.bottom {
        style.set("bottom", value: bottom)
    }
    if let backgroundColor = attributes.backgroundColor {
        style.set("background-color", value: backgroundColor)
    }
    if let rotation = attributes.rotation {
        style.set(
            "transform-origin",
            value: rotation.anchor.css
        )
        style.set(
            "transform",
            value: "rotate(\(rotation.angle.css))"
        )
    }
    if let horizontalAlignment = attributes.horizontalAlignment {
        if width != nil {
            switch horizontalAlignment {
            case .left:
                style.set("text-align", value: "left")
            case .center:
                style.set("text-align", value: "center")
            case .right:
                style.set("text-align", value: "right")
            case .justify:
                style.set("text-align", value: "justify")
            }
        } else {
            print("warning: horizontal alignment has no effect on unbounded text elements")
        }
    }
    var spanStyle = Style()
    spanStyle.set("font", value: attributes.size)
    spanStyle.append("font", value: attributes.family)
    if let textColor = attributes.color {
        spanStyle.set("color", value: textColor)
    }
    if let verticalAlignment = attributes.verticalAlignment {
        if height != nil {
            style.set("display", value: "table")
            spanStyle.set("display", value: "table-cell")
            switch verticalAlignment {
            case .top:
                spanStyle.set("vertical-align", value: "top")
            case .middle:
                spanStyle.set("vertical-align", value: "middle")
            case .bottom:
                spanStyle.set("vertical-align", value: "bottom")
            }
        } else {
            print("warning: vertical alignment has no effect on unbounded text elements")
        }
    }
    return """
    <div\
     class=\"\(classes.joined(separator: " "))\"\
     style=\"\(style.css)\">
    <span style=\"\(spanStyle.css)\">\(content)</span>
    </div>\n
    """
}

private func htmlimage(_ element: Element) -> String {
    guard case let .image(path, inset, width, height, attributes, additional) = element else {
        preconditionFailure()
    }
    let classes = ["component-element"] + additional.classes
    var style = Style()
    if let w = width {
        style.set("width", value: w)
    }
    if let h = height {
        style.set("height", value: h)
    }
    if let top = inset.top {
        style.set("top", value: top)
    }
    if let left = inset.left {
        style.set("left", value: left)
    }
    if let right = inset.right {
        style.set("right", value: right)
    }
    if let bottom = inset.bottom {
        style.set("bottom", value: bottom)
    }
    if let rotation = attributes.rotation {
        style.set(
            "transform-origin",
            value: rotation.anchor.css
        )
        style.set(
            "transform",
            value: "rotate(\(rotation.angle.css))"
        )
    }
    if let mode = attributes.mode {
        if width != nil || height != nil {
            switch mode {
            case .contain:
                style.set("object-fit", value: "contain")
            case .cover:
                style.set("object-fit", value: "cover")
            case .fill:
                style.set("object-fit", value: "fill")
            }
        } else {
            print("warning: scale mode has no effect on unbounded image elements")
        }
    }
    return """
    <img\
     class=\"\(classes.joined(separator: " "))\"\
     src=\"\(path)\"\
     style=\"\(style.css)\">\n
    """
}

private func htmlblock(_ element: Element) -> String {
    guard case let .freeform(content, inset, width, height, attributes, additional) = element else {
        preconditionFailure()
    }
    let classes = ["component-element"] + additional.classes
    var style = Style()
    if let w = width {
        style.set("width", value: w)
    }
    if let h = height {
        style.set("height", value: h)
    }
    if let top = inset.top {
        style.set("top", value: top)
    }
    if let left = inset.left {
        style.set("left", value: left)
    }
    if let right = inset.right {
        style.set("right", value: right)
    }
    if let bottom = inset.bottom {
        style.set("bottom", value: bottom)
    }
    if let rotation = attributes.rotation {
        style.set(
            "transform-origin",
            value: rotation.anchor.css
        )
        style.set(
            "transform",
            value: "rotate(\(rotation.angle.css))"
        )
    }
    return """
    <div\
     class=\"\(classes.joined(separator: " "))\"\
     style=\"\(style.css)\">
    \(content)
    </div>\n
    """
}

private func htmlcomponent(_ element: Element) -> String {
    guard case let .component(component, x, y, rotation) = element else {
        preconditionFailure()
    }
    var contentStyle = Style()

    if let flip = component.attributes.flip {
        // TODO: did we actually want to rotate instead?
        switch flip {
        case .both:
            contentStyle.set("transform", value: "scale(-1, -1)")
        case .vertical:
            contentStyle.set("transform", value: "scale(1, -1)")
        case .horizontal:
            contentStyle.set("transform", value: "scale(-1, 1)")
        }
    }

    let isGuide: (_ element: Element) -> Bool = { elm in
        guard case let .rect(_, _, _, additional) = elm,
              additional.classes.contains("guide")
        else {
            return false
        }
        return true
    }

    let guideElements = component.elements.filter(isGuide)
    let innerElements = component.elements.filter { !isGuide($0) }

    let innerContent = innerElements.map(\.html).joined()
    // TODO: perhaps a distinction whether you want guides above or below content
    let outerContent = guideElements.map(\.html).joined()

    let content = """
    <div\
     class=\"component-content\"\
     style=\"\(contentStyle.css)\">
    \(innerContent)\
    </div>
    \(outerContent)
    """

    var style = Style()
    style.set("top", value: y)
    style.set("left", value: x)
    // note using full extent here; i.e. including bleed
    style.set("width", value: component.parts.full.extent.width)
    style.set("height", value: component.parts.full.extent.height)

    let angle = rotation?.clockwiseOrientedRotation

    let isLandscaped: Bool =
        component.parts.full.extent.width > component.parts.full.extent.height
    // note that we consider portrait orientation the "default", and will rotate
    // any other orientation to fit this; i.e. a card that is oriented as landscape will
    // be rotated to fit in a portrait-oriented position
    let portraitBounds = component.portraitOrientedExtent
    let w = portraitBounds.width.css
    let h = portraitBounds.height.css

    style.set("transform-origin", value: "0% 0%")

    switch angle {
    case .once:
        if isLandscaped {
            // do nothing; natural position (landscape)
        } else {
            style.set("transform", value: "translate(\(h), 0) rotate(\(90.degrees.css))")
        }
    case .twice:
        if isLandscaped {
            style.set("transform", value: "translate(\(w), 0) rotate(\(90.degrees.css))")
        } else {
            style.set("transform", value: "translate(\(w), \(h)) rotate(\(180.degrees.css))")
        }
    case .thrice:
        if isLandscaped {
            style.set("transform", value: "translate(\(h), \(w)) rotate(\(180.degrees.css))")
        } else {
            style.set("transform", value: "translate(0, \(w)) rotate(\(270.degrees.css))")
        }
    case .none:
        if isLandscaped {
            style.set("transform", value: "translate(0, \(h)) rotate(\((-90).degrees.css))")
        } else {
            // do nothing; natural position (portrait)
        }
    }
    return """
    <div\
     class=\"component\"\
     style=\"\(style.css)\">
    \(content)\
    </div>\n
    """
}

private func htmlpage(_ element: Element) -> String {
    guard case let .page(page, margin) = element else {
        preconditionFailure()
    }
    // hack: reduce height slightly to avoid overflow (e.g. "blank" pages)
    // this value is precisely set to what most closely maps to 1 pixel in browser space
    let tweak = 1.inches / 96
    let adjustedPageHeight = page.extent.height - tweak

    let content = page.elements.map(\.html).joined()

    switch page.mode {
    case .relativeToPageMargins:
        let horizontalPadding = margin.width
        let verticalPadding = margin.height
        var style = Style()
        style.set("width", value: page.extent.width)
        style.set("height", value: adjustedPageHeight)
        style.set("padding", value: verticalPadding)
        style.append("padding", value: horizontalPadding)
        return """
        <div\
         class=\"page-frame\"\
         style=\"\(style.css)\">
        <div\
         class=\"page-content\"\
         style=\"width: 100%; height: 100%;\">
        \(content)\
        </div>
        </div>\n
        """
    case .relativeToBoundingBox:
        let inner = page.boundingBox
        // see templates/index.css:.page-frame border, both must match
        let alignmentBorderWidth = 1.millimeters
        // this margin takes into account the alignment border on the inside of the page
        // and the tweaked adjustment of page height (by 1 pixel)
        // this ensures more accurate centering on the final product
        // without the adjustments, the result would have more top margin
        // than bottom margin, making it noticeably less centered than expected
        // (important for layout methods like gutter-fold, less so for most other)
        let verticalMargin = ((adjustedPageHeight - inner.height) / 2) - alignmentBorderWidth + (tweak / 2)
        var style = Style()
        style.set("width", value: page.extent.width)
        style.set("height", value: adjustedPageHeight)
        var innerStyle = Style()
        innerStyle.set("width", value: inner.width)
        innerStyle.set("height", value: inner.height)
        innerStyle.set("margin", value: verticalMargin)
        innerStyle.append("margin", value: "auto")
        return """
        <div\
         class=\"page-frame\"\
         style=\"\(style.css)\">
        <div\
         class=\"page-content\"\
         style=\"\(innerStyle.css)\">
        \(content)\
        </div>
        </div>\n
        """
    }
}

private func htmldoc(_ element: Element) -> String {
    guard case let .document(template, paper, pages) = element else {
        preconditionFailure()
    }
    let pageElements: [Element] = pages.map { .page($0, margin: paper.margin) }
    let pagesHtml = pageElements.map(\.html).joined()

    return template
        .replacingOccurrences(
            of: "{{generator}}",
            with: "swift-boardgame-toolkit \(BoardgameKit.version)"
        )
        .replacingOccurrences(
            of: "{{page_dimensions}}",
            with: "\(paper.extent.width) by \(paper.extent.height)"
        )
        .replacingOccurrences(of: "{{pages}}", with: pagesHtml)
}
