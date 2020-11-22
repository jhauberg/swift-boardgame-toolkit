import Foundation

public struct Repeat: Feature, Composite {
    let children: [Feature]
    public init(times: Int, @FeatureBuilder _ builder: (Int) -> Feature) {
        precondition(times > 0)
        children = For(sequence: 0 ..< times, builder).children
    }

    public let form: Feature? = nil
}
