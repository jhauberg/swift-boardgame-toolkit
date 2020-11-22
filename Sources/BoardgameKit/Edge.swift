import Foundation

public struct Edge: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let top = Edge(rawValue: 1 << 0)
    public static let left = Edge(rawValue: 1 << 1)
    public static let right = Edge(rawValue: 1 << 2)
    public static let bottom = Edge(rawValue: 1 << 3)

    public static let all: Edge = [.top, .right, .bottom, .left]
}
