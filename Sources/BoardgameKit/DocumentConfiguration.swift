import Foundation

public enum DocumentType {
    case web(at: URL)
    case pdf(to: URL)
}

public struct DocumentConfiguration {
    let paper: Paper
    let layouts: [Layout]

    public init(paper: Paper, layouts: [Layout]) {
        self.paper = paper
        self.layouts = layouts
    }

    public static func portrait(with layouts: [Layout]) -> DocumentConfiguration {
        DocumentConfiguration(paper: Paper.a4, layouts: layouts)
    }

    public static func landscape(with layouts: [Layout]) -> DocumentConfiguration {
        DocumentConfiguration(paper: Paper.a4.landscape, layouts: layouts)
    }
}
