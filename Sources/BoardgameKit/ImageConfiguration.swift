import Foundation

public enum ImageType {
    case individual(at: URL)
    case tts(to: URL)
}

public struct ImageConfiguration {
    let dpi: Double
    let components: [Component]

    public init(dpi: Double, components: [Component]) {
        self.dpi = dpi
        self.components = components
    }

    public init(dpi: Double, components: ArraySlice<Component>) {
        self.init(dpi: dpi, components: Array(components))
    }

    public static func print(with components: [Component]) -> ImageConfiguration {
        ImageConfiguration(dpi: 300, components: components)
    }

    public static func print(with components: ArraySlice<Component>) -> ImageConfiguration {
        print(with: Array(components))
    }

    public static func web(with components: [Component]) -> ImageConfiguration {
        ImageConfiguration(dpi: 96, components: components)
    }

    public static func regular(with components: [Component]) -> ImageConfiguration {
        ImageConfiguration(dpi: 150, components: components)
    }

    public static func regular(with components: ArraySlice<Component>) -> ImageConfiguration {
        regular(with: Array(components))
    }
}
