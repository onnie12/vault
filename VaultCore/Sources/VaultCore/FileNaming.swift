import Foundation

/// Turns arbitrary text (a shared file name, a Markdown heading, a path from GitHub)
/// into something safe to use as a single file name inside the Vault store.
///
/// `enum` with only static members is the Swift way of writing a namespace with no
/// instances. It is the rough equivalent of a Go package with only package-level funcs.
public enum FileNaming {

    /// APFS allows 255 UTF-8 bytes per path component, not 255 characters.
    /// An umlaut costs two bytes, so counting characters would let names through
    /// that the filesystem then rejects.
    public static let maxByteLength = 255

    /// Characters that are either illegal in a path component or merely painful.
    /// The forward slash is the important one: without it a name could escape its folder.
    private static let illegalCharacters: Set<Character> = [
        "/", "\\", ":", "*", "?", "\"", "<", ">", "|"
    ]

    /// Makes `rawName` safe to use as one path component.
    ///
    /// The result is never empty: if nothing usable survives, `fallback` is returned.
    public static func sanitize(_ rawName: String, fallback: String = "document") -> String {
        var name = ""
        name.reserveCapacity(rawName.count)

        for character in rawName {
            if illegalCharacters.contains(character) {
                name.append("-")
            } else if character.isNewline || isControlCharacter(character) {
                name.append(" ")
            } else {
                name.append(character)
            }
        }

        name = collapsingRuns(in: name)
        name = trimmingEdges(of: name)

        guard !name.isEmpty else { return fallback }
        return truncating(name, toByteLength: maxByteLength)
    }

    /// The lowercased file extension of `name`, or an empty string when there is none.
    ///
    /// An extension has to be short, alphanumeric and contain at least one letter, so
    /// "Notizen vom 20.09" is treated as having no extension rather than an extension of "09".
    public static func fileExtension(of name: String) -> String {
        guard let dotIndex = name.lastIndex(of: "."), dotIndex != name.startIndex else {
            return ""
        }
        let candidate = name[name.index(after: dotIndex)...]
        guard !candidate.isEmpty, candidate.count <= 10 else { return "" }
        guard candidate.allSatisfy({ $0.isLetter || $0.isNumber }) else { return "" }
        guard candidate.contains(where: { $0.isLetter }) else { return "" }
        return candidate.lowercased()
    }

    // MARK: - Internals

    private static func isControlCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first else {
            return false
        }
        return CharacterSet.controlCharacters.contains(scalar)
    }

    /// Collapses runs of spaces and runs of dashes, so a name full of stripped
    /// characters does not come out as "a---b" or "a   b".
    private static func collapsingRuns(in name: String) -> String {
        var result = ""
        var previous: Character?
        for character in name {
            let isRepeatable = character == " " || character == "-"
            if isRepeatable, character == previous { continue }
            result.append(character)
            previous = character
        }
        return result
    }

    /// Strips leading and trailing dots, spaces and dashes.
    ///
    /// Leading dots matter: without this, "../../etc/passwd" would keep its dots and
    /// a name starting with a dot would create a hidden file.
    private static func trimmingEdges(of name: String) -> String {
        var result = name
        while let first = result.first, first == "." || first == " " || first == "-" {
            result.removeFirst()
        }
        while let last = result.last, last == "." || last == " " || last == "-" {
            result.removeLast()
        }
        return result
    }

    /// Shortens `name` to fit `limit` UTF-8 bytes, keeping the extension when there is one.
    private static func truncating(_ name: String, toByteLength limit: Int) -> String {
        guard name.utf8.count > limit else { return name }

        let ext = fileExtension(of: name)
        var suffix = ext.isEmpty ? "" : ".\(ext)"
        var base = String(name.dropLast(suffix.count))

        // A pathological extension must not eat the whole budget and leave no name.
        if suffix.utf8.count > limit / 2 {
            suffix = ""
            base = name
        }

        while base.utf8.count + suffix.utf8.count > limit, !base.isEmpty {
            base.removeLast()
        }
        base = trimmingEdges(of: base)

        guard !base.isEmpty else { return String(name.prefix(1)) }
        return base + suffix
    }
}
