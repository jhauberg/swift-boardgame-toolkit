import Foundation

/**
 A feature that can be centered within an area.
 */
protocol Centerable: Insettable & Confinable {
    /**
     Center within an area, either horizontally, vertically or both.

     The feature must have dimensionality on the appropriate axis before it can be centered.

     For example, to center horizontally, a feature must have a horizontal dimension (width).

     - Parameters:
       - area: The area in which to center the feature.
       - axis: The axis on which to center the feature.
     - Returns: A centered feature.
     */
    func center(in area: Area, axis: Axis) -> Self
}
