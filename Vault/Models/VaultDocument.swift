import Foundation
import SwiftData

/// One document in Vault. Only metadata lives here; the file itself is on disk
/// at `Application Support/Vault/Files/<storedRelativePath>`.
///
/// `@Model` turns this class into a SwiftData table. Every stored property is a column.
/// Model objects are not thread-safe: use them only inside the actor or view that fetched them.
@Model
final class VaultDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var fileName: String
    var storedRelativePath: String      // relative to Application Support/Vault/Files
    var contentTypeIdentifier: String   // UTType identifier
    var sourceRaw: String               // "shared", "inbox", "picker", "pasted", "github", "export"
    var sourceKey: String?              // GitHub path, or "export:<conversation-uuid>:<artifact-id>"
    var sourceRevision: String?         // GitHub blob SHA, or last artifact version
    var sourceRemoved: Bool             // true if it disappeared from GitHub; never auto-delete
    var contentHash: String             // SHA-256 hex
    var createdAt: Date                 // from the source if known, else import time
    var importedAt: Date
    var updatedAt: Date
    var byteSize: Int
    var textPreview: String             // first ~500 characters, for rows
    var searchText: String?             // first ~50,000 characters of extracted text
    var isFavorite: Bool
    var categoryIsManual: Bool
    var category: VaultCategory?

    init(id: UUID = UUID(), title: String, fileName: String, storedRelativePath: String,
         contentTypeIdentifier: String, sourceRaw: String, contentHash: String,
         createdAt: Date, byteSize: Int, textPreview: String) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.storedRelativePath = storedRelativePath
        self.contentTypeIdentifier = contentTypeIdentifier
        self.sourceRaw = sourceRaw
        self.sourceRemoved = false
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.importedAt = .now
        self.updatedAt = .now
        self.byteSize = byteSize
        self.textPreview = textPreview
        self.isFavorite = false
        self.categoryIsManual = false
    }
}
