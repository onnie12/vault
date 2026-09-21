import Foundation
import SwiftData
import Testing
import UIKit
@testable import Vault

@Suite("DocumentStore")
struct DocumentStoreTests {
    let locations: FileLocations
    let store: DocumentStore

    // Swift Testing creates a fresh instance of this struct for every test,
    // so every test gets its own empty store and temp folder.
    init() throws {
        locations = try FileLocations.temporary()
        store = DocumentStore(modelContainer: try VaultSchema.makeContainer(inMemory: true), locations: locations)
    }

    func importedID(_ outcome: ImportOutcome) throws -> UUID {
        guard case .imported(let id) = outcome else {
            Issue.record("expected .imported, got \(outcome)")
            throw CancellationError()
        }
        return id
    }

    @Test("Importing a file copies it into the store and records it")
    func importsFile() async throws {
        let text = "# M319 Lernziele\n\nVariablen und Schleifen."
        let source = try TestFiles.write("m319-zusammenfassung.md", text)

        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)

        #expect(snapshot.title == "m319-zusammenfassung")
        #expect(snapshot.fileName == "m319-zusammenfassung.md")
        #expect(snapshot.storedRelativePath == "\(id.uuidString)/m319-zusammenfassung.md")
        #expect(snapshot.sourceRaw == "shared")
        #expect(snapshot.contentTypeIdentifier == "net.daringfireball.markdown")
        #expect(snapshot.textPreview == "# M319 Lernziele Variablen und Schleifen.")
        #expect(snapshot.searchText == "# M319 Lernziele Variablen und Schleifen.")
        #expect(snapshot.byteSize == Data(text.utf8).count)

        let stored = locations.fileURL(forRelativePath: snapshot.storedRelativePath)
        #expect(try String(contentsOf: stored, encoding: .utf8) == text)
        #expect(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)),
                "the original must stay where it was")
    }

    @Test("The same bytes under another name are not imported twice")
    func detectsDuplicate() async throws {
        let first = try TestFiles.write("a.md", "same content")
        let second = try TestFiles.write("b.md", "same content")

        let id = try importedID(try await store.importFile(at: first, source: .picker))
        let outcome = try await store.importFile(at: second, source: .picker)

        #expect(outcome == .alreadyInVault(id))
        #expect(try await store.allSnapshots().count == 1)
    }

    @Test("Pasted text becomes a Markdown document titled by its heading")
    func importsPastedText() async throws {
        let id = try importedID(try await store.importPastedText("## Subnetting\nCIDR notes"))
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)

        #expect(snapshot.title == "Subnetting")
        #expect(snapshot.fileName == "Subnetting.md")
        #expect(snapshot.sourceRaw == "pasted")
        #expect(snapshot.textPreview == "## Subnetting CIDR notes")
    }

    @Test("HTML previews show text, not tags")
    func htmlPreview() async throws {
        let source = try TestFiles.write("page.html", "<html><body><h1>Hallo</h1><p>Welt</p></body></html>")
        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        #expect(try #require(found).textPreview == "Hallo Welt")
    }

    @Test("Text is extracted from a PDF")
    func pdfText() async throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        let pdf = renderer.pdfData { context in
            context.beginPage()
            ("Subnetting Grundlagen" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
        }
        let source = try TestFiles.write("notes.pdf", data: pdf)

        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        #expect(try #require(found).searchText?.contains("Subnetting Grundlagen") == true)
    }

    @Test("Files without text get an empty preview and no search text")
    func binaryFile() async throws {
        let source = try TestFiles.write("slides.pptx", data: Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x01]))
        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)
        #expect(snapshot.textPreview == "")
        #expect(snapshot.searchText == nil)
    }

    @Test("Delete removes the record and the file")
    func deletes() async throws {
        let source = try TestFiles.write("temp.txt", "delete me")
        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let folder = locations.filesDirectory.appending(path: id.uuidString, directoryHint: .isDirectory)
        #expect(FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))

        try await store.delete(id)

        #expect(try await store.snapshot(of: id) == nil)
        #expect(!FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
    }

    @Test("Rename changes the title, favorite toggles, unknown ids throw")
    func renameAndFavorite() async throws {
        let source = try TestFiles.write("draft.md", "text")
        let id = try importedID(try await store.importFile(at: source, source: .shared))

        try await store.rename(id, to: "  M117 Subnetting  ")
        try await store.setFavorite(id, true)
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)
        #expect(snapshot.title == "M117 Subnetting")
        #expect(snapshot.isFavorite)

        let unknown = UUID()
        await #expect(throws: DocumentStoreError.notFound(unknown)) {
            try await store.rename(unknown, to: "x")
        }
    }
}
