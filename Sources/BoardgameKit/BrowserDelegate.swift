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
        // experiencing strange log output?
        // see https://stackoverflow.com/q/61338976/144433
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
        // note that the following dimensions should preferably be scaled by screen factor
        // (e.g. / scale), to have the webview produce the correct snapshot, however,
        // this is problematic due to a rounding issue (see below)
        let w = (component.portraitOrientedExtent.width.converted(to: .inches).value * dpi)
        let h = (component.portraitOrientedExtent.height.converted(to: .inches).value * dpi)

        // note that the width given here will actually be "scaled up" depending on backing scale
        // factor (i.e. something like @2x on a high-dpi/Retina screen)
        // this can be problematic, because we want very specific output dimensions, and having
        // to scale this width down may cause rounding issues; e.g. 2x75in@300dpi = 825pixels
        // however, scaling that down before taking a snapshot = 412.5pixels
        // this half-a-pixel will be cut, resulting in only 824pixels final output
        // which is not acceptable in this case
        // to counter this problem, we avoid scaling prior to snapshotting by giving it
        // the full dimension, rounding up if needed (so we always get the larger snapshot), then
        // downsize the snapshot manually afterward- this allows us to get the exact dimensions
        // that we want, without having to upscale
        configuration.snapshotWidth = NSNumber(value: ceil(w))
        webView.takeSnapshot(with: configuration) { image, error in
            guard let image = image else {
                if let error = error {
                    fatalError("\(error)")
                }
                return
            }
            let targetSize = NSSize(width: w, height: h)
            guard let resizedImage = image.resized(to: targetSize) else {
                fatalError()
            }
            let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
            guard let imageData = resizedImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: imageData),
                  let fileData = bitmap.representation(using: .png, properties: properties)
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

extension NSImage {
    func resized(to size: NSSize) -> NSImage? {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        draw(
            in: NSRect(x: 0, y: 0, width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        let resizedImage = NSImage(size: size)
        resizedImage.addRepresentation(bitmapRep)
        return resizedImage
    }
}
