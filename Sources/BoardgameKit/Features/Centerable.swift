import Foundation

/**
 A feature that can be centered in an area.
 */
protocol Centerable: Insettable & Confinable {
    func center(in area: Area, axis: Axis) -> Self
}
