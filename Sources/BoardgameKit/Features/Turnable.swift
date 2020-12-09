import Foundation

/**
 A feature that can be rotated around itself.
 */
protocol Turnable: Feature {
    func turn(_ angle: Angle, from anchor: Anchor) -> Self
}
