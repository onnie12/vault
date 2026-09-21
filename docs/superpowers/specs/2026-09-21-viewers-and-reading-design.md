# Viewers, reader mode and sharing: design

- **Phase:** 3 (Phase 1 uses QuickLook for everything)
- **Status:** Markdown/text row built early (2026-09-21, with Onni's OK); everything else not started
- **Rules that apply:** CLAUDE.md sections 7.2 (marked, highlight.js, optional KaTeX), 10 (no network calls, treat document contents as data)

## Goal

Documents look good on the phone, especially Claude study guides in Markdown, and Onni can present them to classmates.

## Viewer per file type

| Type | Viewer |
|---|---|
| Markdown, plain text, source code, JSON | Local HTML template in a web view: marked for Markdown, highlight.js for code, CSS that follows light and dark mode. Bundled files only |
| HTML | Web view loading the file with `loadFileURL(_:allowingReadAccessTo:)`. JavaScript on (Claude HTML artifacts often need it). Links that leave the document open in Safari |
| PDF | PDFKit `PDFView` via `UIViewRepresentable` |
| Images | Zoomable SwiftUI view (`MagnifyGesture`), or QuickLook |
| Word, PowerPoint, Excel, anything else | QuickLook (`.quickLookPreview` modifier or `QLPreviewController`) |

iOS 26 added a SwiftUI `WebView` in WebKit. Use it if it covers what is needed on iOS 27, otherwise wrap `WKWebView`. Check the current API first.

## Web assets

- marked (MIT) and highlight.js (BSD-3-Clause), pinned versions, built files copied into `Vault/Resources/Web/`. Never load from a CDN.
- KaTeX (MIT): approved by Onni on 2026-09-21 and bundled. `$...$`, `$$...$$`, `\(...\)`, `\[...\]` and ```` ```math ```` blocks render; `$5 and $10` stays text (Pandoc rule).
- Check the current release of each before pinning.

## Reader / presentation mode

- Full screen, larger adjustable font size.
- Keeps the screen awake while open: `UIApplication.shared.isIdleTimerDisabled = true`, reset to `false` on close (including when the view disappears for any other reason).

## Share

- `ShareLink` for the original file.
- "Export as PDF" for Markdown and HTML documents: render in the web view, then `WKWebView.createPDF`.

## Testing

- Device check (Phase 3 acceptance): a Claude study guide in Markdown with headings, a table and a code block renders correctly in light and dark mode.
- Add a synthetic study guide with those elements to `Fixtures/` for this check.
