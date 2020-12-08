import Foundation

public struct For: Feature, Composite {
    let children: [Feature]
    public init<S: Sequence>(sequence: S,
                             @FeatureBuilder _ builder: (_ item: S.Element) -> Feature)
    {
        children = sequence.map(builder)
    }

    public let form: Feature? = nil
}

public struct Repeat: Feature, Composite {
    let children: [Feature]
    public init(times: Int, @FeatureBuilder _ builder: (Int) -> Feature) {
        precondition(times > 0)
        children = For(sequence: 0 ..< times, builder).children
    }

    public let form: Feature? = nil
}
