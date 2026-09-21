import SwiftUI
import UIKit
import WebKit

/// The bundled page (`Resources/Web/markdown.html`) that renders Markdown, code and text.
@MainActor
enum TextTemplate {
    static var url: URL? {
        Bundle.main.url(forResource: "markdown", withExtension: "html", subdirectory: "Web")
    }

    /// A web view set up for local documents: no cookies or website data kept on disk.
    static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: configuration)
    }

    static func load(into webView: WKWebView) {
        guard let url else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    /// Calls `vaultRender` in the page. The text goes in as a real JavaScript
    /// argument, never pasted into code, so nothing in a document can break out.
    static func render(_ payload: TextRenderPayload, in webView: WKWebView) async throws {
        _ = try await webView.callAsyncJavaScript(
            "return vaultRender(payload);",
            arguments: ["payload": payload.javaScriptArgument],
            contentWorld: .page
        )
    }
}

/// A `WKWebView` inside SwiftUI. `UIViewRepresentable` is the bridge for UIKit views
/// SwiftUI has no equivalent for: SwiftUI calls `makeUIView` once and keeps the view.
struct RenderedTextView: UIViewRepresentable {
    let payload: TextRenderPayload

    func makeCoordinator() -> Coordinator {
        Coordinator(payload: payload)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = TextTemplate.makeWebView()
        webView.navigationDelegate = context.coordinator
        // Transparent until the page has drawn, so dark mode never flashes white.
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        TextTemplate.load(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// Receives the web view's callbacks. The coordinator is SwiftUI's place for
    /// delegate objects, similar to passing a handler struct to a Go library.
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let payload: TextRenderPayload

        init(payload: TextRenderPayload) {
            self.payload = payload
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task {
                try? await TextTemplate.render(payload, in: webView)
            }
        }

        /// Only the template itself loads in the web view. Tapped web links open in
        /// Safari (or Mail for mailto:), everything else is ignored.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                return .allow
            }
            if let scheme = url.scheme?.lowercased(), ["http", "https", "mailto", "tel"].contains(scheme) {
                await UIApplication.shared.open(url)
            }
            return .cancel
        }
    }
}
