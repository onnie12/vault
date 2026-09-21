import Foundation
import Testing
@testable import VaultCore

@Suite("TextSnippets")
struct TextSnippetsTests {

    @Test("Preview collapses whitespace into single spaces")
    func previewCollapsesWhitespace() {
        #expect(TextSnippets.preview(of: "# Title\n\n  Some   text\n") == "# Title Some text")
        #expect(TextSnippets.preview(of: " \n\t ") == "")
    }

    @Test("Preview stops at 500 characters")
    func previewLimit() {
        let preview = TextSnippets.preview(of: String(repeating: "a", count: 600))
        #expect(preview.count == 500)
    }

    @Test("Search text keeps the first 50,000 characters, nil when blank")
    func searchText() {
        let long = String(repeating: "b", count: 60_000)
        #expect(TextSnippets.searchText(of: long)?.count == 50_000)
        #expect(TextSnippets.searchText(of: "  \n ") == nil)
    }

    @Test("Decodes UTF-8 and drops a byte order mark")
    func decodesUTF8() {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("Prüfung".utf8)
        #expect(TextSnippets.decodeText(data) == "Prüfung")
    }

    @Test("Decodes UTF-16 little endian with a byte order mark")
    func decodesUTF16() {
        var bytes: [UInt8] = [0xFF, 0xFE]
        for unit in "Hallo".utf16 {
            bytes.append(UInt8(unit & 0xFF))
            bytes.append(UInt8(unit >> 8))
        }
        #expect(TextSnippets.decodeText(Data(bytes)) == "Hallo")
    }

    @Test("Falls back to Windows-1252 for old Windows text files")
    func decodesWindows1252() throws {
        let data = try #require("Prüfung".data(using: .windowsCP1252))
        #expect(TextSnippets.decodeText(data) == "Prüfung")
    }

    @Test("HTML: tags, scripts and styles removed")
    func stripsHTML() {
        let html = "<html><head><style>p{color:red}</style></head><body><h1>Hallo</h1><script>x()</script><p>Welt</p></body></html>"
        #expect(TextSnippets.preview(of: TextSnippets.plainText(fromHTML: html)) == "Hallo Welt")
    }
}
