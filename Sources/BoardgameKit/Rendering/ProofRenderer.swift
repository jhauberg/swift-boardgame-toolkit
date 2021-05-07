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
        var discoveredFonts: [URL] = []
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
                    to: siteUrl.appendingPathComponent(
                        resource.lastPathComponent
                    )
                )
            }

            if let enumerator = FileManager.default.enumerator(at: resourceUrl, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let fileURL as URL in enumerator {
                    do {
                        let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                        if fileAttributes.isRegularFile! {
                            if fileURL.pathExtension == "ttf" {
                                discoveredFonts.append(
                                    URL(string:
                                    fileURL.path.replacingOccurrences(
                                        of: resourceUrl.path + "/",
                                        with: "")
                                        )!
                                )
                            }
                        }
                    } catch { print(error, fileURL) }
                }
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

        let fontFaces: String
        if discoveredFonts.isEmpty {
            fontFaces = "/* no font-faces */"
        } else {
            var adasd: String = ""
            for font in discoveredFonts {
                // todo: note that this solution does not support mixing styles/weights for the same font
                //       this is only a problem if you want to mix styles inline, otherwise you can simply set the font separately
                //       i.e. MyFont and MyFont-Italic
                //       not sure how to solve without exposing an interface to set @font-faces manually
                adasd += """
                @font-face {
                  font-family: \(font.lastPathComponent.replacingOccurrences(of: "." + font.pathExtension, with: ""));
                  src: url(\(font.path));
                }
                """
                // todo: if not last, add newlines as appropriate
            }
            fontFaces = adasd
        }

        let cssUrl = siteUrl.appendingPathComponent("index.css")
        let css = try String(contentsOf: cssUrl, encoding: .utf8)
            .replacingOccurrences(of: "{{pw}}", with: paper.extent.width.css)
            .replacingOccurrences(of: "{{ph}}", with: paper.extent.height.css)
            .replacingOccurrences(of: "{{fonts}}", with: fontFaces) // todo: should also apply to image rendering
        try css.write(to: cssUrl, atomically: true, encoding: .utf8)

        finishRendering()
    }
}
