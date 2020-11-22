import Foundation

protocol Insettable {
    func top(_ distance: Distance) -> Self
    func left(_ distance: Distance) -> Self
    func right(_ distance: Distance) -> Self
    func bottom(_ distance: Distance) -> Self
}
