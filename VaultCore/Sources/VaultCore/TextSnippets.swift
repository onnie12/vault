import Foundation

/// Turns file contents into the two text fields a document row and search need.
public enum TextSnippets {

    public static let previewLength = 500
    public static let searchLength = 50_000

    /// Bytes to text: UTF-8 (with or without BOM), UTF-16 with BOM, else Windows-1252.
    /// Returns nil only when nothing fits.
    public static func decodeText(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(2))
        if bytes == [0xFF, 0xFE] {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if bytes == [0xFE, 0xFF] {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        if let text = String(data: data, encoding: .utf8) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        return String(data: data, encoding: .windowsCP1252)
    }

    /// Rough HTML to text for previews and search. Not a renderer: entities stay as they are.
    public static func plainText(fromHTML html: String) -> String {
        html
            .replacingOccurrences(of: #"(?is)<(script|style)\b.*?</\1>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    }

    /// Short one-paragraph preview for list rows: whitespace runs become one space.
    public static func preview(of text: String) -> String {
        var result = ""
        result.reserveCapacity(previewLength)
        var count = 0
        var pendingSpace = false

        for character in text {
            if character.isWhitespace {
                pendingSpace = count > 0
                continue
            }
            if pendingSpace {
                guard count < previewLength else { break }
                result.append(" ")
                count += 1
                pendingSpace = false
            }
            guard count < previewLength else { break }
            result.append(character)
            count += 1
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// The part of the text that gets indexed for search, or nil when there is nothing to index.
    public static func searchText(of text: String) -> String? {
        let prefix = String(text.prefix(searchLength))
        return prefix.allSatisfy(\.isWhitespace) ? nil : prefix
    }
}
