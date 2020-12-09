import Foundation

/**
 A type that has physical dimensions.
 */
protocol Dimensioned {
    var extent: Size { get }
}
