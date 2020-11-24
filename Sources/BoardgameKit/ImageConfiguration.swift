import Foundation

public enum ImageType {
    case individual(at: URL)
    case tts(to: URL)
}

public struct ImageConfiguration {
    let dpi: Int
    let components: [Component]

    public static func custom(dpi: Int, with components: [Component]) -> ImageConfiguration {
        ImageConfiguration(dpi: dpi, components: components)
    }

    public static func print(with components: [Component]) -> ImageConfiguration {
        custom(dpi: 300, with: components)
    }

    public static func regular(with components: [Component]) -> ImageConfiguration {
        custom(dpi: 150, with: components)
    }

    public static func web(with components: [Component]) -> ImageConfiguration {
        custom(dpi: 96, with: components)
    }

    public static func custom(dpi: Int, with components: ArraySlice<Component>) -> ImageConfiguration {
        custom(dpi: dpi, with: Array(components))
    }

    public static func print(with components: ArraySlice<Component>) -> ImageConfiguration {
        self.print(with: Array(components))
    }

    public static func regular(with components: ArraySlice<Component>) -> ImageConfiguration {
        regular(with: Array(components))
    }

    public static func web(with components: ArraySlice<Component>) -> ImageConfiguration {
        web(with: Array(components))
    }
}
