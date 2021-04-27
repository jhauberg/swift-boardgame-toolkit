import Foundation

public enum ImagesTarget {
    case png(at: URL? = nil)
    case tts(to: URL)
}

public struct ImagesConfiguration {
    let dpi: Int
    let components: [Component]
    let format: String

    public static func custom(
        dpi: Int,
        arranging components: [Component],
        format: String = "%03d"
    ) -> ImagesConfiguration {
        ImagesConfiguration(dpi: dpi, components: components, format: format)
    }

    public static func print(
        arranging components: [Component]
    ) -> ImagesConfiguration {
        custom(dpi: 300, arranging: components)
    }

    public static func regular(
        arranging components: [Component]
    ) -> ImagesConfiguration {
        custom(dpi: 150, arranging: components)
    }

    public static func web(
        arranging components: [Component]
    ) -> ImagesConfiguration {
        custom(dpi: 96, arranging: components)
    }
}

public extension ImagesConfiguration {
    static func custom(
        dpi: Int,
        arranging components: ArraySlice<Component>
    ) -> ImagesConfiguration {
        custom(dpi: dpi, arranging: Array(components))
    }

    static func print(
        arranging components: ArraySlice<Component>
    ) -> ImagesConfiguration {
        print(arranging: Array(components))
    }

    static func regular(
        arranging components: ArraySlice<Component>
    ) -> ImagesConfiguration {
        regular(arranging: Array(components))
    }

    static func web(
        arranging components: ArraySlice<Component>
    ) -> ImagesConfiguration {
        web(arranging: Array(components))
    }
}
