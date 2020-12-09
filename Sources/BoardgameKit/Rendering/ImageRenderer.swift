import Foundation
import WebKit

final class ImageRenderer: Renderer {
    private struct Rendition {
        let index: Int
        let component: Component
        let format: String
    }

    private let dpi: Double
    private let format: String
    private let template: String
    private let resourceUrl: URL?
    private let directoryUrl: URL

    private var queue: [Component]
    private var current: Rendition?

    init(configuration: ImagesConfiguration, destinationUrl: URL?, resourceUrl: URL?) throws {
        guard let templateUrl = Bundle.module.resourceURL?
                .appendingPathComponent("templates/render/index.html") else {
            fatalError()
        }

        template = try String(contentsOf: templateUrl, encoding: .utf8)

        self.dpi = Double(configuration.dpi)
        self.format = configuration.format
        self.queue = configuration.components.reversed()
        self.resourceUrl = resourceUrl
        self.directoryUrl = destinationUrl ?? URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        ).appendingPathComponent("images")

        try FileManager.default.createDirectory(
            at: directoryUrl,
            withIntermediateDirectories: true,
            attributes: nil
        )

        super.init()
    }

    private func render(rendition: Rendition) {
        let component = rendition.component
        let dimensions = component.portraitOrientedExtent
        // this is required to get correct sizing; see snapshot to apply desired dpi
        let nativeDPI: Double = 96
        let w = dimensions.width.converted(to: .inches).value * nativeDPI
        let h = dimensions.height.converted(to: .inches).value * nativeDPI

        let element: Element = .component(component, x: .zero, y: .zero)
        let content = template.replacingOccurrences(of: "{{component}}", with: element.html)

        current = rendition

        webView.navigationDelegate = self
        webView.frame = NSRect(origin: .zero, size: CGSize(width: w, height: h))
        // experiencing strange log output?
        // see https://stackoverflow.com/q/61338976/144433
        webView.loadHTMLString(content, baseURL: resourceUrl)

        beginRendering()
    }

    override func render() {
        guard !queue.isEmpty else {
            return
        }

        guard let component = queue.popLast() else {
            return
        }

        let indexOffset = current?.index ?? 0

        render(
            rendition: Rendition(
                index: 1 + indexOffset, // start from 1; not zero- just a preference for files
                component: component,
                format: format))
    }
}

extension ImageRenderer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard let rendition = current else {
            fatalError()
        }

        let configuration = WKSnapshotConfiguration()
        let dimensions = rendition.component.portraitOrientedExtent
        // note that the following dimensions should preferably be scaled by screen factor
        // (e.g. / scale), to have the webview produce the correct snapshot, however,
        // this is problematic due to a rounding issue (see below)
        let w = (dimensions.width.converted(to: .inches).value * dpi)
        let h = (dimensions.height.converted(to: .inches).value * dpi)

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

            let fileUrl = self.directoryUrl.appendingPathComponent(
                String(format: rendition.format, rendition.index).appending(".png"))

            do {
                try fileData.write(to: fileUrl, options: .atomic)
            } catch {
                fatalError()
            }

            self.finishRendering()

            if let back = rendition.component.back {
                self.render(
                    rendition: Rendition(
                        index: rendition.index, // note using same index; i.e. not incrementing
                        component: back,
                        format: rendition.format + "_back"))
            } else {
                self.render()
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
