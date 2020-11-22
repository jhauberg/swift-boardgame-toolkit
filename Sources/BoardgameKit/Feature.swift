import Foundation

public protocol Feature {
    @FeatureBuilder var form: Feature? { get }
}

extension Feature {
    func flatten() -> [Feature] {
        var elms: [Feature] = []
        if let container = self as? Composite {
            for child in container.children {
                elms.append(contentsOf: child.flatten())
            }
        } else if let body = form {
            elms.append(contentsOf: body.flatten())
        } else {
            elms.append(self)
        }
        return elms
    }
}

extension Feature {
    func elements() -> [Element] {
        flatten()
            .compactMap { $0 as? ElementConvertible }
            .map(\.element)
    }
}

protocol Composite {
    var children: [Feature] { get }
}

struct Group: Feature, Composite {
    let children: [Feature]
    let form: Feature? = nil
}

public struct For: Feature, Composite {
    let children: [Feature]
    public init<S: Sequence>(sequence: S,
                             @FeatureBuilder _ builder: (_ item: S.Element) -> Feature)
    {
        children = sequence.map(builder)
    }

    public let form: Feature? = nil
}
