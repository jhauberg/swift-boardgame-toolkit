import Foundation

protocol Insettable {
    func top(_ inset: Distance) -> Self
    func left(_ inset: Distance) -> Self
    func right(_ inset: Distance) -> Self
    func bottom(_ inset: Distance) -> Self
}
