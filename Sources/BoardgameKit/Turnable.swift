import Foundation

protocol Turnable {
    func turn(_ angle: Angle, from anchor: Anchor) -> Self
}
