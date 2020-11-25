import Foundation

public enum DocumentType {
    case web(at: URL)
    case pdf(to: URL)
}

public struct DocumentConfiguration {
    let paper: Paper
    let layouts: [Layout]

    public static func portrait(on paper: Paper = .a4, arranging layouts: [Layout]) -> DocumentConfiguration {
        DocumentConfiguration(paper: paper.portrait, layouts: layouts)
    }

    public static func landscape(on paper: Paper = .a4, arranging layouts: [Layout]) -> DocumentConfiguration {
        DocumentConfiguration(paper: paper.landscape, layouts: layouts)
    }
}
