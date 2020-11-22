import Foundation

protocol Confinable {
    func width(_ width: Distance, height: Distance?) -> Self
    func height(_ height: Distance) -> Self
}
