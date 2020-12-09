import Foundation

final class ProofRenderer: Renderer {
    private let directoryUrl: URL
    private let resourceUrl: URL?
    private let paper: Paper
    private let pages: [Page]

    init(configuration: DocumentConfiguration, pages: [Page], destinationUrl: URL?, resourceUrl: URL?) throws {
        self.pages = pages
        self.paper = configuration.paper
        self.resourceUrl = resourceUrl
        self.directoryUrl = destinationUrl ?? URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    }

    override func render() throws {
        let siteUrl = directoryUrl.appendingPathComponent("proof")
        try FileManager.default.createDirectory(
            at: directoryUrl,
            withIntermediateDirectories: true,
            attributes: nil
        )
        // remove any existing directory; note that we don't need to handle "no such file" exception
        try? FileManager.default.removeItem(at: siteUrl)
        guard let templateSiteUrl = Bundle.module.resourceURL?
                .appendingPathComponent("templates/proof")
        else {
            fatalError()
        }
        try FileManager.default.copyItem(at: templateSiteUrl, to: siteUrl)
        if let assetsUrl = resourceUrl?.appendingPathComponent("assets") {
            try FileManager.default.copyItem(
                at: assetsUrl, to: siteUrl.appendingPathComponent("assets")
            )
        }

        let indexUrl = siteUrl.appendingPathComponent("index.html")
        let index = try String(contentsOf: indexUrl, encoding: .utf8)

        let doc = Element.document(
            template: index,
            paper: paper,
            pages: pages
        )
        try doc.html.write(to: indexUrl, atomically: true, encoding: .utf8)

        let cssUrl = siteUrl.appendingPathComponent("index.css")
        let css = try String(contentsOf: cssUrl, encoding: .utf8)
            .replacingOccurrences(of: "{{pw}}", with: paper.extent.width.css)
            .replacingOccurrences(of: "{{ph}}", with: paper.extent.height.css)
        try css.write(to: cssUrl, atomically: true, encoding: .utf8)

        finishRendering()
    }
}
