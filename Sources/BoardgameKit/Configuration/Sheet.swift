import Foundation

public struct SheetDescription {
    let title: String?
    let author: String?
    let copyright: String?

    public init(
        title: String? = nil,
        author: String? = nil,
        copyright: String? = nil
    ) {
        self.title = title
        self.author = author
        self.copyright = copyright
    }
}

public struct Sheet {
    public let description: SheetDescription?

    let bundle: Bundle?

    public init(
        description: SheetDescription? = nil,
        bundle: Bundle? = nil
    ) {
        self.description = description
        self.bundle = bundle
    }

    public func images(target: ImagesTarget, configuration: ImagesConfiguration) throws {
        guard !configuration.components.isEmpty else {
            print("warning: configuration did not provide any components; no images generated")
            return
        }
        switch target {
        case let .png(url):
            let images = try ImageRenderer(
                configuration: configuration,
                destinationUrl: url,
                resourceUrl: bundle?.resourceURL
            )

            images.render()

        case .tts:
            fatalError("not implemented yet")
        }
    }

    public func document(target: DocumentTarget, configuration: DocumentConfiguration) throws {
        guard !configuration.layouts.isEmpty else {
            print("warning: configuration did not provide any layouts; document not generated")
            return
        }
        switch target {
        case let .proof(url):
            let pages = arrange(using: configuration)

            let doc = try ProofRenderer(
                configuration: configuration,
                pages: pages,
                destinationUrl: url,
                resourceUrl: bundle?.resourceURL
            )
            try doc.render()

        case let .pdf(url):
            let tempLocationUrl = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("swift-boardgame-toolkit")
            try FileManager.default.createDirectory(
                at: tempLocationUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )

            try document(target: .proof(at: tempLocationUrl), configuration: configuration)
            let proofUrl = tempLocationUrl.appendingPathComponent("proof")
            guard FileManager.default.fileExists(atPath: proofUrl.path) else {
                fatalError()
            }

            let doc = PDFRenderer(
                locationUrl: proofUrl,
                destinationUrl: url,
                paper: configuration.paper,
                meta: description
            )
            try doc.render()

            try FileManager.default.removeItem(at: tempLocationUrl)
        }
    }

    private func arrange(using configuration: DocumentConfiguration) -> [Page] {
        var pages: [Page] = []

        for layout in configuration.layouts.splitBySize {
            pages.append(
                contentsOf:
                    layout.pages(on: configuration.paper)
            )
        }

        return pages
    }
}

private extension Array where Element == Layout {
    // if a layout contains mixed-size components, this splits the layouts up into separate,
    // individual layouts, ultimately forcing page-breaks so that every page contains
    // only one size of component
    var splitBySize: [Layout] {
        var sanitizedLayouts: [Layout] = []
        for layout in self {
            if case .custom = layout.method {
                // don't mess with this type of layout; mixing sizes is allowed here
                sanitizedLayouts.append(layout)
                continue
            }
            var previousComponentSize: Size?
            var collected: [Component] = []
            var chunks: [[Component]] = []
            for component in layout.components {
                if let previousSize = previousComponentSize,
                   previousSize.width != component.portraitOrientedExtent.width ||
                   previousSize.height != component.portraitOrientedExtent.height
                {
                    chunks.append(collected)
                    collected = []
                }

                collected.append(component)

                previousComponentSize = component.portraitOrientedExtent
            }
            if !collected.isEmpty {
                chunks.append(collected)
                collected = []
            }
            for chunk in chunks {
                sanitizedLayouts.append(Layout(chunk, method: layout.method))
            }
        }
        return sanitizedLayouts
    }
}
