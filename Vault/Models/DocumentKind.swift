import UniformTypeIdentifiers

/// Picks the SF Symbol shown on a row. Order matters: HTML, source code and JSON
/// all conform to plain text too, so the specific checks come first.
enum DocumentKind {
    static func symbolName(for contentTypeIdentifier: String) -> String {
        guard let type = UTType(contentTypeIdentifier) else { return "doc" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .html) { return "globe" }
        if type.conforms(to: .sourceCode) || type.conforms(to: .json) {
            return "chevron.left.forwardslash.chevron.right"
        }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .presentation) { return "rectangle.on.rectangle" }
        if type.conforms(to: .spreadsheet) { return "tablecells" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }
}

/// How the built-in text viewer shows a file, or nil when QuickLook shows it instead.
enum TextViewerMode: String, Sendable {
    case markdown, code, text

    /// Markdown, plain text, source code and JSON open in the text viewer (viewers spec).
    /// HTML, RTF and CSV are text too, but QuickLook shows them better for now.
    init?(contentTypeIdentifier: String) {
        guard let type = UTType(contentTypeIdentifier), type.conforms(to: .text) else { return nil }
        if type.conforms(to: .html) || type.conforms(to: .rtf) || type.conforms(to: .delimitedText) {
            return nil
        }
        if let markdown = UTType("net.daringfireball.markdown"), type.conforms(to: markdown) {
            self = .markdown
        } else if type.conforms(to: .plainText) && !type.conforms(to: .sourceCode) {
            self = .text
        } else {
            self = .code
        }
    }
}
