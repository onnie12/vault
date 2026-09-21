import Foundation

/// Picks a human-readable title for a new document.
public enum DocumentTitle {

    public static let maxLength = 80
    public static let fallback = "Pasted document"

    /// Title for text pasted from the clipboard (source S4): the first Markdown
    /// heading, else the first non-empty line, cut to `maxLength` characters.
    public static func forPastedText(_ text: String) -> String {
        // `split` returns Substrings (views into the original, like a Go slice of a string).
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let candidate = lines.lazy.compactMap { headingText($0) }.first ?? lines.first ?? ""
        let title = String(candidate.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? fallback : title
    }

    /// Title for an imported file: its name without the extension.
    public static func forFileName(_ fileName: String) -> String {
        let ext = FileNaming.fileExtension(of: fileName)
        let base = ext.isEmpty ? fileName : String(fileName.dropLast(ext.count + 1))
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fileName : trimmed
    }

    /// "## Lernziele" -> "Lernziele". Nil when the line is not an ATX heading.
    static func headingText(_ line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        // A closing sequence like "## Title ##" is Markdown syntax, not part of the title.
        let withoutClosing = text.replacingOccurrences(of: #"\s+#+$"#, with: "", options: .regularExpression)
        return withoutClosing.isEmpty ? nil : withoutClosing
    }
}
