import Foundation

@resultBuilder
public enum FeatureBuilder {
    public static func buildBlock(_ features: Feature...) -> Feature {
        Group(children: features)
    }

    public static func buildArray(_ features: [Feature]) -> Feature {
        Group(children: features)
    }

    public static func buildEither(first feature: Feature) -> Feature {
        feature
    }

    public static func buildEither(second feature: Feature) -> Feature {
        feature
    }

    public static func buildOptional(_ feature: Feature?) -> Feature {
        feature ?? Group(children: [])
    }

    public static func buildFinalResult(_ feature: Feature) -> Feature {
        feature
    }
}
