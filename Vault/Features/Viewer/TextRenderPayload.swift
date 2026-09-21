import Foundation
import VaultCore

/// Everything the web template needs to draw one document. A plain `Sendable`
/// value, so it can be built off the main actor and handed to the view.
struct TextRenderPayload: Sendable, Equatable {
    let mode: TextViewerMode
    /// highlight.js language name for code files: the file extension, for example "swift" or "sh".
    let language: String
    let text: String

    /// The argument for `vaultRender(payload)` in markdown.js.
    var javaScriptArgument: [String: String] {
        ["mode": mode.rawValue, "language": language, "text": text]
    }

    /// Reads and decodes the file. `@concurrent` makes this run on a background
    /// thread even when called from the main actor, so a big file never freezes
    /// the UI (a bit like starting a goroutine and waiting for its result).
    @concurrent
    static func load(fileURL: URL, mode: TextViewerMode) async throws -> TextRenderPayload {
        let data = try Data(contentsOf: fileURL)
        guard let text = TextSnippets.decodeText(data) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        let language = FileNaming.fileExtension(of: fileURL.lastPathComponent).lowercased()
        return TextRenderPayload(mode: mode, language: language, text: text)
    }
}
