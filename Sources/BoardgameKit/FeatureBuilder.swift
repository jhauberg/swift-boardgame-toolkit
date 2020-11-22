import Foundation

@_functionBuilder
public enum FeatureBuilder {
    public static func buildBlock(_ component: Feature) -> Feature {
        component
    }

    public static func buildBlock(_ children: Feature...) -> Feature {
        Group(children: children)
    }

    public static func buildIf(_ component: Feature?) -> Feature {
        component ?? Group(children: [])
    }

    public static func buildEither(first: Feature) -> Feature {
        first
    }

    public static func buildEither(second: Feature) -> Feature {
        second
    }

    // intentionally leaving out buildDo, as catch clauses do not seem to
    // currently be supported in @_functionBuilder
}
