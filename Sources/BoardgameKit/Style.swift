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
        set(key, value: value.css)
    }

    mutating func append(_ key: String, value: Measurement<UnitLength>) {
        append(key, value: value.css)
    }
}

extension Style: CSSConvertible {
    var css: String {
        items.keys.sorted().map { key in
            "\(key): \(items[key]!)"
        }.joined(separator: "; ")
    }
}

extension Measurement: CSSConvertible {
    var css: String {
        // to allow for the two extensions on UnitLength and UnitAngle;
        // otherwise we'd have conflicting conformances
        // (i.e. more than one `Measurement: CSSConvertible where ...`)
        fatalError()
    }
}

extension Measurement where UnitType == UnitLength {
    var css: String {
        switch unit {
        case .inches:
            return "\(value)in"
        case .millimeters:
            return "\(value)mm"
        case .centimeters:
            return "\(value)cm"
        default:
            return converted(to: .inches).css
        }
    }
}

extension Measurement where UnitType == UnitAngle {
    var css: String {
        switch unit {
        case .degrees:
            return "\(value)deg"
        default:
            return converted(to: .degrees).css
        }
    }
}
