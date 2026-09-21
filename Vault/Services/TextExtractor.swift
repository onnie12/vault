import Foundation
import PDFKit
import UniformTypeIdentifiers
import VaultCore

/// Pulls searchable text out of a file's bytes. Phase 1 handles text-like files,
/// HTML and PDFs. Word, PowerPoint and Excel get no text; QuickLook still shows them.
enum TextExtractor {
    static func text(from data: Data, type: UTType) -> String? {
        if type.conforms(to: .pdf) {
            return PDFDocument(data: data)?.string
        }
        guard type.conforms(to: .text), let text = TextSnippets.decodeText(data) else {
            return nil
        }
        return type.conforms(to: .html) ? TextSnippets.plainText(fromHTML: text) : text
    }
}
