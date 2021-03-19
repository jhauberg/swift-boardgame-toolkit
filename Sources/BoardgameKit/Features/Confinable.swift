import Foundation

/**
 A feature that can have dimensionality (either horizontally, vertically or both).

 The difference between the `Dimensioned` and `Confinable` types is that a `Dimensioned` type
 _always_ has dimensionality (on both axes), whereas a `Confinable` type _may_ have dimensionality
 (and not necessarily on both axes).
 */
protocol Confinable: Feature {
    func width(_ width: Distance, height: Distance?) -> Self
    func height(_ height: Distance) -> Self
}
