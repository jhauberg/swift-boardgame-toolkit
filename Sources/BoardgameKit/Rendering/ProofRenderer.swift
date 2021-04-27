import Foundation

final class ProofRenderer: Renderer {
    private let directoryUrl: URL
    private let resourceUrl: URL?
    private let paper: Paper
    private let pages: [Page]

    init(
        configuration: DocumentConfiguration,
        pages: [Page],
        destinationUrl: URL?,
        resourceUrl: URL?
    ) throws {
        self.pages = pages
        paper = configuration.paper
        self.resourceUrl = resourceUrl
        directoryUrl = destinationUrl ?? URL(
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
            .appendingPathComponent("Templates/Proof")
        else {
            fatalError()
        }
        try FileManager.default.copyItem(at: templateSiteUrl, to: siteUrl)
        // provided that an URL for .bundle/Contents/Resources has been specified,
        // copy over all files as-is to the proof directory
        if let resourceUrl = resourceUrl {
            let resourceUrls = try FileManager.default.contentsOfDirectory(
                at: resourceUrl,
                includingPropertiesForKeys: [],
                options: [.skipsHiddenFiles]
            )
            for resource in resourceUrls {
                #if DEBUG
                print("Copying \"\(resource.lastPathComponent)\" ...")
                #endif
                try FileManager.default.copyItem(
                    at: resource,
                    to: siteUrl.appendingPathComponent(resource.lastPathComponent)
                )
            }
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
