import Foundation

/**
 A feature that can be confined in either dimension.
 */
protocol Confinable: Feature {
    func width(_ width: Distance, height: Distance?) -> Self
    func height(_ height: Distance) -> Self
}
