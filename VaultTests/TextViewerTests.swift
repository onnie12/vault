import Foundation
import Testing
import UIKit
import WebKit
@testable import Vault

@Suite("TextViewerMode")
struct TextViewerModeTests {

    @Test("Markdown, text and code open in the text viewer")
    func textViewerTypes() {
        #expect(TextViewerMode(contentTypeIdentifier: "net.daringfireball.markdown") == .markdown)
        #expect(TextViewerMode(contentTypeIdentifier: "public.plain-text") == .text)
        #expect(TextViewerMode(contentTypeIdentifier: "public.swift-source") == .code)
        #expect(TextViewerMode(contentTypeIdentifier: "public.shell-script") == .code)
        #expect(TextViewerMode(contentTypeIdentifier: "public.json") == .code)
    }

    @Test("HTML, RTF, CSV, PDF, images and Office files stay with QuickLook")
    func quickLookTypes() {
        for identifier in ["public.html", "public.rtf", "public.comma-separated-values-text", "com.adobe.pdf",
                           "public.png", "org.openxmlformats.wordprocessingml.document", "not.a.real.type"] {
            #expect(TextViewerMode(contentTypeIdentifier: identifier) == nil, "\(identifier)")
        }
    }

    @Test("Loading a file keeps its text and uses the extension as the code language")
    func loadPayload() async throws {
        let url = try TestFiles.write("fix-grub.sh", "sudo grub-install")
        let payload = try await TextRenderPayload.load(fileURL: url, mode: .code)
        #expect(payload == TextRenderPayload(mode: .code, language: "sh", text: "sudo grub-install"))
    }
}

/// Renders documents with the real bundled template in a real web view.
@MainActor
@Suite("Text template", .serialized)
struct TextTemplateTests {

    /// Waits for the web view to finish loading, like a Go channel receive.
    final class LoadWaiter: NSObject, WKNavigationDelegate {
        var continuation: CheckedContinuation<Void, any Error>?
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            continuation?.resume()
            continuation = nil
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: any Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func rendered(_ markdown: String, mode: TextViewerMode = .markdown, language: String = "md",
                  style: UIUserInterfaceStyle = .light) async throws -> (WKWebView, LoadWaiter) {
        #expect(TextTemplate.url != nil, "markdown.html is missing from the app bundle")
        let webView = TextTemplate.makeWebView()
        webView.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        webView.overrideUserInterfaceStyle = style
        let waiter = LoadWaiter()
        webView.navigationDelegate = waiter
        try await withCheckedThrowingContinuation { continuation in
            waiter.continuation = continuation
            TextTemplate.load(into: webView)
        }
        try await TextTemplate.render(TextRenderPayload(mode: mode, language: language, text: markdown), in: webView)
        return (webView, waiter)
    }

    func count(_ selector: String, in webView: WKWebView) async throws -> Int {
        let result = try await webView.callAsyncJavaScript(
            "return document.querySelectorAll(selector).length;",
            arguments: ["selector": selector], contentWorld: .page)
        return (result as? NSNumber)?.intValue ?? -1
    }

    func text(_ selector: String, in webView: WKWebView) async throws -> String? {
        try await webView.callAsyncJavaScript(
            "const element = document.querySelector(selector); return element ? element.textContent : null;",
            arguments: ["selector": selector], contentWorld: .page) as? String
    }

    @Test("A study guide gets headings, a scrollable table and highlighted code")
    func studyGuide() async throws {
        let (webView, _) = try await rendered("""
            # M117 Subnetting

            ## Tabelle

            | Prefix | Hosts |
            |---|---|
            | /24 | 254 |

            ```bash
            if [ -f /etc/hosts ]; then echo ok; fi
            ```
            """)
        #expect(try await text("h1", in: webView) == "M117 Subnetting")
        #expect(try await count("h2", in: webView) == 1)
        #expect(try await count(".table-scroll > table td", in: webView) == 2)
        #expect(try await count("pre code.hljs .hljs-keyword", in: webView) > 0)
    }

    @Test("Inline and block math become KaTeX, prices stay text")
    func math() async throws {
        let (webView, _) = try await rendered("""
            Die Parabel $y = x^2 + 3x$ hat den Scheitelpunkt \\(S(-1.5 | -2.25)\\).

            $$
            x_{1,2} = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
            $$

            Das Buch kostet $5 und das Heft $10.
            """)
        #expect(try await count(".katex", in: webView) == 3)
        #expect(try await count(".math-block .katex-display", in: webView) == 1)
        let last = try await webView.callAsyncJavaScript(
            "return Array.from(document.querySelectorAll('p')).pop().textContent;",
            arguments: [:], contentWorld: .page) as? String
        #expect(last == "Das Buch kostet $5 und das Heft $10.")
    }

    @Test("Scripts inside a document never run")
    func documentScriptsAreBlocked() async throws {
        let (webView, _) = try await rendered("""
            <img src="missing.png" onerror="window.pwned = 1">
            <script>window.pwned = 2</script>
            [link](javascript:window.pwned=3)
            """)
        try await Task.sleep(for: .milliseconds(500))
        let pwned = try await webView.callAsyncJavaScript(
            "return window.pwned === undefined ? 0 : window.pwned;", arguments: [:], contentWorld: .page)
        #expect((pwned as? NSNumber)?.intValue == 0)
    }

    @Test("A single line break is kept, like in Claude's answers")
    func lineBreaks() async throws {
        let (webView, _) = try await rendered("**Interviewer:** Joe\n**Length:** 4 minutes")
        #expect(try await count("p", in: webView) == 1)
        #expect(try await count("p > br", in: webView) == 1)
    }

    @Test("Plain text is escaped, not interpreted")
    func plainText() async throws {
        let (webView, _) = try await rendered("<b>not bold</b>\nline 2", mode: .text, language: "txt")
        #expect(try await count("b", in: webView) == 0)
        #expect(try await text("pre.plain-text", in: webView) == "<b>not bold</b>\nline 2")
    }
}
