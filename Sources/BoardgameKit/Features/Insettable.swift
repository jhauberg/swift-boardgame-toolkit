import Foundation

/**
 A feature that can be inset from any edge in an area.
 */
protocol Insettable: Feature {
    func top(_ inset: Distance) -> Self
    func left(_ inset: Distance) -> Self
    func right(_ inset: Distance) -> Self
    func bottom(_ inset: Distance) -> Self
}
