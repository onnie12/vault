import Foundation

public enum LibrarySearch {

    /// True when every word of `query` appears in at least one of `fields`,
    /// ignoring case and diacritics ("prufung" finds "Prüfung"). Nil fields are skipped.
    public static func matches(_ query: String, fields: [String?]) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = fields.compactMap { $0 }.joined(separator: "\n")
        return words.allSatisfy { word in
            haystack.range(of: String(word), options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
