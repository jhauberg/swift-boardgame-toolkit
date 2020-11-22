import Foundation

public struct Anchor: Equatable {
    let x: Double
    let y: Double

    public init(x: Double, y: Double) {
        precondition(x <= 1 && x >= 0)
        precondition(y <= 1 && y >= 0)
        self.x = x
        self.y = y
    }

    public static let center = Anchor(x: 0.5, y: 0.5)
    public static let left = Anchor(x: 0, y: center.y)
    public static let right = Anchor(x: 1, y: center.y)

    public static let top = Anchor(x: center.x, y: 0)
    public static let topLeft = Anchor(x: left.x, y: top.y)
    public static let topRight = Anchor(x: right.x, y: top.y)

    public static let bottom = Anchor(x: center.x, y: 1)
    public static let bottomLeft = Anchor(x: left.x, y: bottom.y)
    public static let bottomRight = Anchor(x: right.x, y: bottom.y)
}
