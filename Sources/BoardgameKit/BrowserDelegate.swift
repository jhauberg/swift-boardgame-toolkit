import Foundation
import WebKit

public enum BrowserDelegatePDFError: Error, Equatable {
    case notFound(at: URL)
}

class BrowserDelegatePDF: NSObject, WKNavigationDelegate {
    private let browser: WKWebView
    private let destinationUrl: URL
    var paperSize: Paper?

    private var finishedRendering: Bool = false
    var shouldKeepRunning: Bool {
        !finishedRendering
    }

    init(destinationUrl: URL) {
        self.destinationUrl = destinationUrl
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        browser = WKWebView(frame: .zero, configuration: config)
    }

    func load(siteUrl: URL) throws {
        browser.navigationDelegate = self
        let indexUrl = siteUrl.appendingPathComponent("index.html")
        guard FileManager.default.fileExists(atPath: indexUrl.path) else {
            throw BrowserDelegatePDFError.notFound(at: indexUrl)
        }
        browser.loadFileURL(indexUrl, allowingReadAccessTo: siteUrl)
    }

    @objc func fin(
        printOperation: NSPrintOperation,
        succes _: Bool,
        contextInfo _: UnsafeRawPointer
    ) {
        finishedRendering = true
        printOperation.cleanUp()
        printOperation.destroyContext()
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        let printInfo = NSPrintInfo(
            dictionary: [
                NSPrintInfo.AttributeKey.jobDisposition: NSPrintInfo.JobDisposition.save,
                NSPrintInfo.AttributeKey.jobSavingURL: destinationUrl,
                NSPrintInfo.AttributeKey.detailedErrorReporting: NSNumber(booleanLiteral: false),
            ]
        )

        printInfo.verticalPagination = .clip
        printInfo.horizontalPagination = .clip

        printInfo.bottomMargin = 0
        printInfo.topMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0

        if let paper = paperSize {
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
        }

        if printInfo.paperSize.width >= printInfo.paperSize.height {
            printInfo.orientation = .landscape
        } else {
            printInfo.orientation = .portrait
        }

        // note unretained value; we don't want to manage this object
        if let operation = webView.perform(
            Selector(("_printOperationWithPrintInfo:")),
            with: printInfo
        )?.takeUnretainedValue() as? NSPrintOperation {
            operation.showsPrintPanel = false
            operation.showsProgressPanel = false

            operation.runModal(
                for: NSWindow(),
                delegate: self,
                didRun: #selector(fin(printOperation:succes:contextInfo:)),
                contextInfo: nil
            )
        }
    }
}

class BrowserDelegate: NSObject, WKNavigationDelegate {
    private let browser: WKWebView
    private let template: String
    private let resourceURL: URL?
    private let scale: Double
    private var queue: [Component] = []

    var dpi: Double = 300

    let destinationUrl: URL

    init(template: String, url: URL, resourceURL: URL?, components: [Component]) {
        self.template = template
        self.resourceURL = resourceURL
        destinationUrl = url
        queue.append(contentsOf: components)
        // we have to determine screen scale; i.e. high dpi/retina screen might be 2 or 3
        // we have to know this because we want to render output in scale=1
        if let screen = NSScreen.main {
            scale = Double(screen.backingScaleFactor)
        } else {
            scale = 1
        }

        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        browser = WKWebView(frame: .zero, configuration: config)
    }

    func renderNext() {
        guard let component = queue.last else {
            return
        }

        let element: Element = .component(component, x: .zero, y: .zero)
        let renderHtml = template.replacingOccurrences(of: "{{component}}", with: element.html)

        // this is required to get correct sizing; see snapshot to apply desired dpi
        let nativeDPI: Double = 96
        let w = component.portraitOrientedExtent.width.converted(to: .inches).value * nativeDPI
        let h = component.portraitOrientedExtent.height.converted(to: .inches).value * nativeDPI

        browser.navigationDelegate = self
        browser.frame = NSRect(origin: .zero, size: CGSize(width: w, height: h))
        browser.loadHTMLString(renderHtml, baseURL: resourceURL)
    }

    var shouldKeepRunning: Bool {
        !queue.isEmpty
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard let component = queue.last else {
            return
        }
        let configuration = WKSnapshotConfiguration()
        let w = (component.portraitOrientedExtent.width.converted(to: .inches).value * dpi) / scale
        configuration.snapshotWidth = NSNumber(value: w)
        webView.takeSnapshot(with: configuration) { image, error in
            guard let image = image else {
                if let error = error {
                    print(error)
                }
                return
            }

            let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
            guard let imageData = image.tiffRepresentation,
                  let imageRep = NSBitmapImageRep(data: imageData),
                  let fileData = imageRep.representation(using: .png, properties: properties)
            else {
                return
            }

            let fileUrl = self.destinationUrl
                .appendingPathComponent("output_\(self.queue.count).png")
            try! fileData.write(to: fileUrl, options: .atomic)

            // finally pop it once we have processed it
            _ = self.queue.popLast()
            // and continue on to the next, if any
            if !self.queue.isEmpty {
                self.renderNext()
            }
        }
    }
}
