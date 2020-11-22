import Foundation

protocol Centerable: Insettable, Confinable {
    func center(in area: Area, axis: Axis) -> Self
}
