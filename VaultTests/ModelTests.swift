import Foundation
import SwiftData
import Testing
@testable import Vault

@Suite("Models")
struct ModelTests {

    @Test("A document can be saved and fetched from an in-memory store")
    func saveAndFetch() throws {
        let container = try VaultSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let document = VaultDocument(
            title: "M319 Lernziele", fileName: "m319.md", storedRelativePath: "x/m319.md",
            contentTypeIdentifier: "public.plain-text", sourceRaw: DocumentSource.pasted.rawValue,
            contentHash: "abc", createdAt: .now, byteSize: 3, textPreview: "M319")
        context.insert(document)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<VaultDocument>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "M319 Lernziele")
        #expect(fetched.first?.isFavorite == false)
        #expect(fetched.first?.categoryIsManual == false)
        #expect(fetched.first?.sourceRemoved == false)
    }

    @Test("Source badges match the spec: Shared, Pasted, GitHub, Export")
    func badges() {
        #expect(DocumentSource.shared.badge == "Shared")
        #expect(DocumentSource.inbox.badge == "Shared")
        #expect(DocumentSource.picker.badge == "Shared")
        #expect(DocumentSource.pasted.badge == "Pasted")
        #expect(DocumentSource.github.badge == "GitHub")
        #expect(DocumentSource.export.badge == "Export")
    }

    @Test("Each kind of file gets its SF Symbol")
    func symbols() {
        #expect(DocumentKind.symbolName(for: "com.adobe.pdf") == "doc.richtext")
        #expect(DocumentKind.symbolName(for: "public.png") == "photo")
        #expect(DocumentKind.symbolName(for: "public.html") == "globe")
        #expect(DocumentKind.symbolName(for: "public.swift-source") == "chevron.left.forwardslash.chevron.right")
        #expect(DocumentKind.symbolName(for: "public.plain-text") == "doc.text")
        #expect(DocumentKind.symbolName(for: "public.zip-archive") == "doc.zipper")
        #expect(DocumentKind.symbolName(for: "not.a.real.type") == "doc")
    }
}
