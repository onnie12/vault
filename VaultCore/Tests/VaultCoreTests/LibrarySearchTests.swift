import Testing
@testable import VaultCore

@Suite("LibrarySearch")
struct LibrarySearchTests {

    @Test("An empty query matches everything")
    func emptyQuery() {
        #expect(LibrarySearch.matches("", fields: ["anything"]))
        #expect(LibrarySearch.matches("   ", fields: [nil]))
    }

    @Test("Ignores case and diacritics")
    func caseAndDiacritics() {
        #expect(LibrarySearch.matches("m319", fields: ["M319 Lernziele"]))
        #expect(LibrarySearch.matches("prufung", fields: ["M122 Prüfung"]))
    }

    @Test("Every word must appear, in any field")
    func allWords() {
        let fields: [String?] = ["fix-grub", nil, "sudo grub-install on CachyOS"]
        #expect(LibrarySearch.matches("grub cachyos", fields: fields))
        #expect(!LibrarySearch.matches("grub fedora", fields: fields))
    }
}
