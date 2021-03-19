import Foundation

/**
 A type that has dimensionality (horizontally and vertically).
 */
protocol Dimensioned {
    var extent: Size { get }
}
