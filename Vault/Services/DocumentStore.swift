import Foundation
import SwiftData
import UniformTypeIdentifiers
import VaultCore

/// What happened to one import.
enum ImportOutcome: Sendable, Equatable {
    case imported(UUID)
    /// The same bytes are already stored; carries the existing document's id.
    case alreadyInVault(UUID)
}

/// A plain copy of a document's fields. `@Model` objects must not cross actors,
/// so this `Sendable` struct is what leaves the store.
struct DocumentSnapshot: Sendable, Equatable {
    let id: UUID
    let title: String
    let fileName: String
    let storedRelativePath: String
    let contentTypeIdentifier: String
    let sourceRaw: String
    let contentHash: String
    let byteSize: Int
    let textPreview: String
    let searchText: String?
    let isFavorite: Bool
}

extension DocumentSnapshot {
    init(_ document: VaultDocument) {
        self.init(id: document.id, title: document.title, fileName: document.fileName,
                  storedRelativePath: document.storedRelativePath,
                  contentTypeIdentifier: document.contentTypeIdentifier,
                  sourceRaw: document.sourceRaw, contentHash: document.contentHash,
                  byteSize: document.byteSize, textPreview: document.textPreview,
                  searchText: document.searchText, isFavorite: document.isFavorite)
    }
}

enum DocumentStoreError: Error, Equatable {
    case notFound(UUID)
}

/// The only place that writes documents: files on disk and SwiftData records.
///
/// An `actor` is a type whose methods run one at a time, off the main thread.
/// Think of a goroutine that owns its state and serves requests over a channel;
/// callers `await` each method. `ModelActor` gives it its own SwiftData context.
/// Written out by hand instead of with the `@ModelActor` macro, because the
/// macro's generated init cannot take the extra `locations` parameter.
actor DocumentStore: ModelActor {
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer
    nonisolated let locations: FileLocations

    init(modelContainer: ModelContainer, locations: FileLocations) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.locations = locations
    }

    // MARK: - Import

    /// Copies the file at `url` into the store. The caller handles security-scoped access.
    func importFile(at url: URL, source: DocumentSource) throws -> ImportOutcome {
        let data = try Data(contentsOf: url)
        return try importData(data, rawFileName: url.lastPathComponent, title: nil, source: source)
    }

    /// Saves pasted text as a Markdown document (source S4).
    func importPastedText(_ text: String) throws -> ImportOutcome {
        let title = DocumentTitle.forPastedText(text)
        return try importData(Data(text.utf8), rawFileName: title + ".md", title: title, source: .pasted)
    }

    private func importData(_ data: Data, rawFileName: String, title: String?,
                            source: DocumentSource) throws -> ImportOutcome {
        let hash = ContentHash.sha256Hex(of: data)
        if let existing = try document(withHash: hash) {
            return .alreadyInVault(existing.id)
        }

        let id = UUID()
        let fileName = FileNaming.sanitize(rawFileName)
        let folder = locations.filesDirectory.appending(path: id.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appending(path: fileName, directoryHint: .notDirectory), options: .atomic)

        let ext = FileNaming.fileExtension(of: fileName)
        let type = ext.isEmpty ? UTType.data : (UTType(filenameExtension: ext) ?? .data)
        let text = TextExtractor.text(from: data, type: type)

        let document = VaultDocument(
            id: id,
            title: title ?? DocumentTitle.forFileName(fileName),
            fileName: fileName,
            storedRelativePath: "\(id.uuidString)/\(fileName)",
            contentTypeIdentifier: type.identifier,
            sourceRaw: source.rawValue,
            contentHash: hash,
            createdAt: .now,
            byteSize: data.count,
            textPreview: text.map { TextSnippets.preview(of: $0) } ?? ""
        )
        document.searchText = text.flatMap { TextSnippets.searchText(of: $0) }
        modelContext.insert(document)

        do {
            try modelContext.save()
        } catch {
            // Keep disk and database in step: no file without a record.
            modelContext.rollback()
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return .imported(id)
    }

    // MARK: - Changes

    /// Deletes the record first, then the file. A leftover file is harmless;
    /// a record pointing at a missing file is not.
    func delete(_ id: UUID) throws {
        guard let document = try document(withID: id) else { throw DocumentStoreError.notFound(id) }
        modelContext.delete(document)
        try modelContext.save()

        let folder = locations.filesDirectory.appending(path: id.uuidString, directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: folder)
        }
    }

    /// Changes the title shown in the library. The file on disk keeps its name.
    func rename(_ id: UUID, to newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document = try document(withID: id) else { throw DocumentStoreError.notFound(id) }
        guard !trimmed.isEmpty else { return }
        document.title = trimmed
        document.updatedAt = .now
        try modelContext.save()
    }

    func setFavorite(_ id: UUID, _ isFavorite: Bool) throws {
        guard let document = try document(withID: id) else { throw DocumentStoreError.notFound(id) }
        document.isFavorite = isFavorite
        document.updatedAt = .now
        try modelContext.save()
    }

    // MARK: - Reading

    func snapshot(of id: UUID) throws -> DocumentSnapshot? {
        try document(withID: id).map { DocumentSnapshot($0) }
    }

    func allSnapshots() throws -> [DocumentSnapshot] {
        try modelContext.fetch(FetchDescriptor<VaultDocument>()).map { DocumentSnapshot($0) }
    }

    private func document(withID id: UUID) throws -> VaultDocument? {
        var descriptor = FetchDescriptor<VaultDocument>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func document(withHash hash: String) throws -> VaultDocument? {
        var descriptor = FetchDescriptor<VaultDocument>(predicate: #Predicate { $0.contentHash == hash })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
