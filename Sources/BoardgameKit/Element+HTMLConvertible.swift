import Foundation

struct Style {
    private var items: [String: String] = [:]

    mutating func set(_ key: String, value: String) {
        var k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let end = k.last, end == ":" {
            k = String(k[..<k.endIndex])
        }
        if let end = v.last, end == ";" {
            v = String(v[..<v.endIndex])
        }
        items[k] = v
    }

    mutating func append(_ key: String, value: String) {
        guard let existingValue = items[key] else {
            fatalError()
        }

        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let end = v.last, end == ";" {
            v = String(v[..<v.endIndex])
        }
        items[key] = existingValue.appending(" ").appending(v)
    }

    mutating func set(_ key: String, value: Measurement<UnitLength>) {
        set(key, value: "\(String(value.converted(to: .inches).value))in")
    }

    mutating func append(_ key: String, value: Measurement<UnitLength>) {
        append(key, value: "\(String(value.converted(to: .inches).value))in")
    }
}

protocol CSSConvertible {
    var css: String { get }
}

extension Style: CSSConvertible {
    var css: String {
        items.keys.sorted().map { key in
            "\(key): \(items[key]!)"
        }.joined(separator: "; ")
    }
}

extension Element: HTMLConvertible {
    var html: String {
        switch self {
        case let .rect(inset, bounds, attr, additional):
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
            if let backgroundColor = attr.backgroundColor {
                style.set("background-color", value: backgroundColor)
            }
            if let borderRadius = attr.borderRadius {
                style.set("border-radius", value: borderRadius)
            }
            if let borderColor = attr.borderColor,
               let borderStyle = attr.borderStyle,
               let borderWidth = attr.borderWidth,
               let borderEdges = attr.borderEdges
            {
                if borderEdges == .all {
                    style.set("border", value: borderWidth)
                    style.append("border", value: borderStyle)
                    style.append("border", value: borderColor)
                } else {
                    if borderEdges.contains(.top) {
                        style.set("border-top", value: borderWidth)
                        style.append("border-top", value: borderStyle)
                        style.append("border-top", value: borderColor)
                    }
                    if borderEdges.contains(.right) {
                        style.set("border-right", value: borderWidth)
                        style.append("border-right", value: borderStyle)
                        style.append("border-right", value: borderColor)
                    }
                    if borderEdges.contains(.bottom) {
                        style.set("border-bottom", value: borderWidth)
                        style.append("border-bottom", value: borderStyle)
                        style.append("border-bottom", value: borderColor)
                    }
                    if borderEdges.contains(.left) {
                        style.set("border-left", value: borderWidth)
                        style.append("border-left", value: borderStyle)
                        style.append("border-left", value: borderColor)
                    }
                }
            }
            if let outerBorderColor = attr.outerBorderColor,
               let outerBorderWidth = attr.outerBorderWidth
            {
                style.set("box-shadow", value: "0 0 0")
                style.append("box-shadow", value: outerBorderWidth)
                style.append("box-shadow", value: outerBorderColor)
            }
            if let rotation = attr.rotation {
                style.set(
                    "transform-origin",
                    value: "\(rotation.anchor.x * 100)% \(rotation.anchor.y * 100)%"
                )
                style.set(
                    "transform",
                    value: "rotate(\(String(rotation.angle.converted(to: .degrees).value))deg)"
                )
            }
            return """
            <div\
             class=\"\(classes.joined(separator: " "))\"\
             style=\"\(style.css)\">\
            </div>\n
            """

        case let .text(content, inset, width, height, attr, additional):
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
            if let rotation = attr.rotation {
                style.set(
                    "transform-origin",
                    value: "\(rotation.anchor.x * 100)% \(rotation.anchor.y * 100)%"
                )
                style.set(
                    "transform",
                    value: "rotate(\(String(rotation.angle.converted(to: .degrees).value))deg)"
                )
            }
            if let horizontalAlignment = attr.horizontalAlignment {
                if width != nil {
                    switch horizontalAlignment {
                    case .left:
                        style.set("text-align", value: "left")
                    case .middle:
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
            spanStyle.set("font", value: attr.size)
            spanStyle.append("font", value: attr.family)
            if let textColor = attr.color {
                spanStyle.set("color", value: textColor)
            }
            if let verticalAlignment = attr.verticalAlignment {
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

        case let .image(path, inset, width, height, attr, additional):
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
            if let rotation = attr.rotation {
                style.set(
                    "transform-origin",
                    value: "\(rotation.anchor.x * 100)% \(rotation.anchor.y * 100)%"
                )
                style.set(
                    "transform",
                    value: "rotate(\(String(rotation.angle.converted(to: .degrees).value))deg)"
                )
            }
            if let mode = attr.mode {
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

        case let .component(component, x, y, rotation):

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

            let innerContent = component.elements.map(\.html).joined()
            let content = """
            <div\
             class=\"component-content\"\
             style=\"\(contentStyle.css)\">
            \(innerContent)\
            </div>\n
            """

            var style = Style()
            style.set("top", value: y)
            style.set("left", value: x)
            style.set("width", value: component.full.extent.width)
            style.set("height", value: component.full.extent.height)

            let angle = rotation?.clockwiseOrientedRotation

            let isLandscaped: Bool = component.full.extent.width > component.full.extent.height
            let portraitBounds = component.portraitOrientedBounds
            let w = portraitBounds.width.converted(to: .inches).value
            let h = portraitBounds.height.converted(to: .inches).value

            style.set("transform-origin", value: "0% 0%")

            switch angle {
            case .once:
                if isLandscaped {
                    // do nothing; natural position (landscape)
                } else {
                    style.set("transform", value: "translate(\(h)in, 0) rotate(90deg)")
                }
            case .twice:
                if isLandscaped {
                    style.set("transform", value: "translate(\(w)in, 0) rotate(90deg)")
                } else {
                    style.set("transform", value: "translate(\(w)in, \(h)in) rotate(180deg)")
                }
            case .thrice:
                if isLandscaped {
                    style.set("transform", value: "translate(\(h)in, \(w)in) rotate(180deg)")
                } else {
                    style.set("transform", value: "translate(0, \(w)in) rotate(270deg)")
                }
            case .none:
                if isLandscaped {
                    style.set("transform", value: "translate(0, \(h)in) rotate(-90deg)")
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

        case let .page(page, margin):
            // hack: reduce height slightly to avoid overflow (e.g. "blank" pages)
            // it can be higher or lower; there's no specific distance that is correct,
            // but as low as possible without introducing overflow is preferable;
            // the distance required can vary from browser to browser
            let h = page.bounds.height - 0.25.millimeters

            let content = page.elements.map(\.html).joined()

            switch page.mode {
            case .relativeToPageMargins:
                let horizontalPadding = margin.width
                let verticalPadding = margin.height
                var style = Style()
                style.set("width", value: page.bounds.width)
                style.set("height", value: h)
                style.set("padding", value: verticalPadding)
                style.append("padding", value: horizontalPadding)
                return """
                <div\
                 class=\"page\"\
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
                let verticalMargin = (h - inner.height) / 2
                var style = Style()
                style.set("width", value: page.bounds.width)
                style.set("height", value: h)
                var innerStyle = Style()
                innerStyle.set("width", value: inner.width)
                innerStyle.set("height", value: inner.height)
                innerStyle.set("margin", value: verticalMargin)
                innerStyle.append("margin", value: "auto")
                return """
                <div\
                 class=\"page\"\
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
    }
}
