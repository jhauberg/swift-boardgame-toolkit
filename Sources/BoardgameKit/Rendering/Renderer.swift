import Foundation
import WebKit

class Renderer: NSObject {
    private var hasFinishedRendering: Bool = false

    var webView: WKWebView

    override init() {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        webView = WKWebView(frame: .zero, configuration: config)
    }

    // TODO: preferably protected; only subclasses should have access here
    func beginRendering() {
        hasFinishedRendering = false
        while RunLoop.current.run(mode: .default, before: .distantFuture) {
            if hasFinishedRendering {
                break
            }
        }
    }

    func render() throws {
        fatalError("must be called on subclass")
    }

    // TODO: preferably protected; only subclasses should have access here
    func finishRendering() {
        hasFinishedRendering = true
    }
}
