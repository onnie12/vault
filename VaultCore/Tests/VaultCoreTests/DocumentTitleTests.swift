import Testing
@testable import VaultCore

@Suite("DocumentTitle")
struct DocumentTitleTests {

    @Test("Pasted text: the first Markdown heading wins")
    func headingWins() {
        #expect(DocumentTitle.forPastedText("# M319 Lernziele\n\nText") == "M319 Lernziele")
        #expect(DocumentTitle.forPastedText("Intro line\n## Subnetting\nmore") == "Subnetting")
    }

    @Test("Pasted text: without a heading, the first non-empty line")
    func firstLineFallback() {
        #expect(DocumentTitle.forPastedText("Milch, Brot\nEier") == "Milch, Brot")
        #expect(DocumentTitle.forPastedText("\n\n   Hello  \n") == "Hello")
    }

    @Test("A hashtag is not a heading, a closing ## is not part of the title")
    func headingSyntax() {
        #expect(DocumentTitle.forPastedText("#todo buy milk") == "#todo buy milk")
        #expect(DocumentTitle.forPastedText("## Title ##") == "Title")
        #expect(DocumentTitle.forPastedText("## Learning C#") == "Learning C#")
    }

    @Test("Pasted text: cut to 80 characters, fallback when empty")
    func lengthAndFallback() {
        let long = String(repeating: "a", count: 200)
        #expect(DocumentTitle.forPastedText(long) == String(repeating: "a", count: 80))
        #expect(DocumentTitle.forPastedText("  \n \n") == "Pasted document")
    }

    @Test("File name: drop the extension, keep names that have none")
    func fromFileName() {
        #expect(DocumentTitle.forFileName("m319-zusammenfassung.md") == "m319-zusammenfassung")
        #expect(DocumentTitle.forFileName("Makefile") == "Makefile")
        #expect(DocumentTitle.forFileName("Notizen vom 20.09") == "Notizen vom 20.09")
    }
}
