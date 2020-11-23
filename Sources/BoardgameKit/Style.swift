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

extension Style: CSSConvertible {
    var css: String {
        items.keys.sorted().map { key in
            "\(key): \(items[key]!)"
        }.joined(separator: "; ")
    }
}
