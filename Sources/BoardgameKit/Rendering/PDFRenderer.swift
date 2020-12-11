import Foundation
import WebKit
#if os(macOS)
    import Quartz.PDFKit
#endif

final class PDFRenderer: Renderer {
    private let paper: Paper
    private let meta: SheetDescription?
    private let locationUrl: URL
    private let destinationUrl: URL

    init(locationUrl: URL, destinationUrl: URL, paper: Paper, meta: SheetDescription?) {
        self.paper = paper
        self.meta = meta
        self.destinationUrl = destinationUrl
        self.locationUrl = locationUrl
    }

    override func render() throws {
        try FileManager.default.createDirectory(
            at: destinationUrl.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let indexUrl = locationUrl.appendingPathComponent("index.html")

        guard FileManager.default.fileExists(atPath: indexUrl.path) else {
            fatalError()
        }

        webView.navigationDelegate = self
        webView.loadFileURL(indexUrl, allowingReadAccessTo: locationUrl)

        beginRendering()
    }

    private func attachMetadata() {
        #if os(macOS)
            guard let doc = PDFDocument(url: destinationUrl),
                  var metadata = doc.documentAttributes
            else {
                fatalError()
            }
            do {
                try FileManager.default.removeItem(at: destinationUrl)
            } catch {
                fatalError()
            }
            metadata[PDFDocumentAttribute.creatorAttribute] =
                "swift-boardgame-toolkit \(BoardgameKit.version)"
            if let title = meta?.title {
                metadata[PDFDocumentAttribute.titleAttribute] = title
            }
            if let author = meta?.author {
                metadata[PDFDocumentAttribute.authorAttribute] = author
            }
            if let copyright = meta?.copyright {
                metadata[PDFDocumentAttribute.subjectAttribute] = copyright
            }
            doc.documentAttributes = metadata
            if !doc.write(to: destinationUrl) {
                fatalError()
            }
        #endif
    }

    @objc func printOperationDidFinish(
        printOperation: NSPrintOperation,
        succes _: Bool,
        contextInfo _: UnsafeRawPointer
    ) {
        printOperation.cleanUp()
        printOperation.destroyContext()

        guard FileManager.default.fileExists(atPath: destinationUrl.path) else {
            fatalError()
        }

        attachMetadata()
        finishRendering()
    }
}

extension PDFRenderer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        let printInfo = NSPrintInfo(
            dictionary: [
                NSPrintInfo.AttributeKey.jobDisposition: NSPrintInfo.JobDisposition.save,
                // todo: URLs like `URL(fileURLWithPath: "output.pdf")` trigger output:
                //         CFURLGetFSRef was passed an URL which has no scheme (the URL will not work with other CFURL routines)
                //         CFURLCopyResourcePropertyForKey failed because it was passed an URL which has no scheme
                //       though it still works as expected, these warnings are distracting
                //       (also, `destinationUrl.scheme` is "file" in this case, so what is the problem really?)
                NSPrintInfo.AttributeKey.jobSavingURL: destinationUrl,
                NSPrintInfo.AttributeKey.detailedErrorReporting: NSNumber(booleanLiteral: true),
            ]
        )

        printInfo.verticalPagination = .clip
        printInfo.horizontalPagination = .clip

        printInfo.bottomMargin = 0
        printInfo.topMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0

        let userSpaceDPI: Double = 72
        // paper sizes and margins are calculated in a 72 dpi coordinate space; example:
        // A4 = 8,27in (21cm) x 11.69in (29.7cm)
        //    = 8,27x72       x 11.69x72
        //    = 595px (round) x 842px (round)
        let w: Double = paper.extent.width.converted(to: .inches).value * userSpaceDPI
        let h: Double = paper.extent.height.converted(to: .inches).value * userSpaceDPI

        printInfo.paperSize = NSSize(
            width: w, height: h
        )

        if printInfo.paperSize.width >= printInfo.paperSize.height {
            printInfo.orientation = .landscape
        } else {
            printInfo.orientation = .portrait
        }

        // note unretained value; we don't want to manage this object
        guard let operation = webView.perform(
            Selector(("_printOperationWithPrintInfo:")),
            with: printInfo
        )?.takeUnretainedValue() as? NSPrintOperation else {
            fatalError()
        }

        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.runModal(
            for: NSWindow(),
            delegate: self,
            didRun: #selector(printOperationDidFinish(printOperation:succes:contextInfo:)),
            contextInfo: nil
        )
    }
}
