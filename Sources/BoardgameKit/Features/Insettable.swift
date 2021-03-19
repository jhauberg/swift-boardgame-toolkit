import Foundation

/**
 A feature that can be inset from the edges of an area.

 Insets are directionally mutually-exclusive for the same axis; this means that a top inset
 can not exist alongside a bottom inset; only the latter would apply.
 */
protocol Insettable: Feature {
    func top(_ inset: Distance) -> Self
    func left(_ inset: Distance) -> Self
    func right(_ inset: Distance) -> Self
    func bottom(_ inset: Distance) -> Self
}
