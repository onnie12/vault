import Testing
@testable import VaultCore

// Swift Testing (the `import Testing` framework) replaced XCTest for new tests.
// `@Test` marks a test function, `#expect` is the assertion. A failing #expect
// records the failure and lets the rest of the function run.
@Suite("FileNaming")
struct FileNamingTests {

    @Test("Leaves an already safe name alone")
    func keepsSafeName() {
        #expect(FileNaming.sanitize("m319-zusammenfassung.md") == "m319-zusammenfassung.md")
    }

    @Test("A path traversal attempt cannot produce a separator or a hidden file")
    func blocksPathTraversal() {
        let result = FileNaming.sanitize("../../etc/passwd")
        #expect(result == "etc-passwd")
        #expect(!result.contains("/"))
        #expect(!result.hasPrefix("."))
    }

    @Test("Replaces characters that are illegal in a file name")
    func replacesIllegalCharacters() {
        #expect(FileNaming.sanitize("report: v2.md") == "report- v2.md")
    }

    @Test("Falls back when nothing usable is left")
    func fallsBackOnEmptyInput() {
        #expect(FileNaming.sanitize("   ") == "document")
        #expect(FileNaming.sanitize("...") == "document")
        #expect(FileNaming.sanitize("", fallback: "pasted.md") == "pasted.md")
    }

    @Test("Truncates to 255 UTF-8 bytes and keeps the extension")
    func truncatesLongNames() {
        // Umlauts cost two UTF-8 bytes each, which is the case that breaks a
        // character-counting implementation.
        let long = String(repeating: "ü", count: 400) + ".md"
        let result = FileNaming.sanitize(long)

        #expect(result.utf8.count <= FileNaming.maxByteLength)
        #expect(result.hasSuffix(".md"))
    }

    @Test("Reads the file extension, lowercased")
    func readsFileExtension() {
        #expect(FileNaming.fileExtension(of: "main.go") == "go")
        #expect(FileNaming.fileExtension(of: "README.MD") == "md")
        #expect(FileNaming.fileExtension(of: "archive.7z") == "7z")
    }

    @Test("Does not mistake a date or a dotfile for an extension")
    func rejectsNonExtensions() {
        #expect(FileNaming.fileExtension(of: "Notizen vom 20.09") == "")
        #expect(FileNaming.fileExtension(of: "Makefile") == "")
        #expect(FileNaming.fileExtension(of: ".gitignore") == "")
    }
}
