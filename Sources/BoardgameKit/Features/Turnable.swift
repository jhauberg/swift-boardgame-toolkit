import Foundation

/**
 A feature that can be rotated around itself.
 */
protocol Turnable: Feature {
    /**
     Rotate at an angle around an anchor point.

     - Parameters:
       - angle: The angle at which to rotate the feature.
       - anchor: The relative point to rotate the feature around.
     - Returns: A rotated feature.
     */
    func turn(_ angle: Angle, from anchor: Anchor) -> Self
}
