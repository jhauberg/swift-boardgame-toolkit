import Foundation

public enum ImageType {
    case individual(at: URL)
    case tts(to: URL)
}

public struct ImageConfiguration {
    let dpi: Int
    let components: [Component]

    public static func custom(dpi: Int, arranging components: [Component]) -> ImageConfiguration {
        ImageConfiguration(dpi: dpi, components: components)
    }

    public static func print(arranging components: [Component]) -> ImageConfiguration {
        custom(dpi: 300, arranging: components)
    }

    public static func regular(arranging components: [Component]) -> ImageConfiguration {
        custom(dpi: 150, arranging: components)
    }

    public static func web(arranging components: [Component]) -> ImageConfiguration {
        custom(dpi: 96, arranging: components)
    }

    public static func custom(dpi: Int, arranging components: ArraySlice<Component>) -> ImageConfiguration {
        custom(dpi: dpi, arranging: Array(components))
    }

    public static func print(arranging components: ArraySlice<Component>) -> ImageConfiguration {
        self.print(arranging: Array(components))
    }

    public static func regular(arranging components: ArraySlice<Component>) -> ImageConfiguration {
        regular(arranging: Array(components))
    }

    public static func web(arranging components: ArraySlice<Component>) -> ImageConfiguration {
        web(arranging: Array(components))
    }
}
