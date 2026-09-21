# Library, storage and import: design

- **Phase:** 1 (library list and import), with the category parts of the library UI landing in Phase 2
- **Status:** not started
- **Rules that apply:** CLAUDE.md sections 3.1 (no App Groups, so no Share Extension), 7.2 (dependencies), 7.5 (concurrency), 10 (privacy)
- **Related specs:** classification (categories, filter chips), viewers (Phase 3 viewers)

## Goal

Get documents into Vault by hand, store them safely, and show them in one searchable list.

## Storage

- Document files: `Application Support/Vault/Files/<document-uuid>/<sanitized-file-name>`. File names go through `VaultCore.FileNaming.sanitize`.
- Metadata: SwiftData store.
- Never store file contents in SwiftData.
- De-duplicate by SHA-256 of the file bytes (`apple/swift-crypto`, `import Crypto`). Importing an identical file again shows "Already in Vault" and opens the existing document.
- `DocumentStore` (in `Vault/Services/`) owns copy, hash, de-duplicate and delete. File I/O and hashing run off the main actor.

## SwiftData models (starting point, adjust as needed)

```swift
import Foundation
import SwiftData

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

@Model
final class VaultCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbolName: String
    var colorHex: String
    var order: Int
    var isFallback: Bool
    var matchesImageTypes: Bool
    var rulesData: Data                 // JSON-encoded VaultCore.CategoryRules
    @Relationship(deleteRule: .nullify, inverse: \VaultDocument.category)
    var documents: [VaultDocument] = []

    init(id: UUID = UUID(), name: String, symbolName: String, colorHex: String, order: Int,
         isFallback: Bool = false, matchesImageTypes: Bool = false, rulesData: Data) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.order = order
        self.isFallback = isFallback
        self.matchesImageTypes = matchesImageTypes
        self.rulesData = rulesData
    }
}
```

`VaultCategory` is created in Phase 1 so the schema is stable, but seeded and used only from Phase 2 on (classification spec).

## Sources

### S1: "Open in Vault" from the share sheet (no extension needed)

- Declare document types in `Info.plist` (`CFBundleDocumentTypes`, `LSHandlerRank = Alternate`) for: plain text, Markdown, HTML, PDF, images, source code, JSON, ZIP, Word, PowerPoint, Excel.
- Markdown may not be a system-declared type on iOS **[unverified]**. If it is not, add a `UTImportedTypeDeclarations` entry for `net.daringfireball.markdown` with extensions `md` and `markdown`.
- Receive files in SwiftUI with `.onOpenURL`. Call `startAccessingSecurityScopedResource()` before reading, copy the file into the Vault store, then `stopAccessingSecurityScopedResource()`.
- **Confirm on the device** that Vault appears in the share sheet for a PDF and a `.md` file **[unverified]**. If it does not, S2 is the fallback.

### S2: "Add to Vault" folder in the Files app

- Set `UIFileSharingEnabled = YES` and `LSSupportsOpeningDocumentsInPlace = YES`. The app's `Documents` folder then shows up in the Files app under On My iPhone > Vault.
- Create `Documents/Add to Vault/`. Not `Documents/Inbox/`: iOS reserves that name on a real iPhone and the app gets "permission denied" (error 513) creating it **[verified 2026-09-21 on Onni's iPhone]**; the simulator does not enforce this. Onni can "Save to Files" into it from any app, including the Claude app.
- On launch and whenever the scene becomes active, import everything in `Add to Vault/`, then remove the originals from it only after a successful import.

### S3: File picker

- `.fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection: true)`, same security-scoped copy as S1.

### S4: Paste as document

- Use SwiftUI `PasteButton` (avoids the paste permission prompt). Save the text as `.md`. Title = first Markdown heading, else first line, max 80 characters.
- This covers Claude answers that exist only in the chat: Onni copies the answer in the Claude app and pastes it into Vault.

## Library screen (main screen)

Phase 1:

- One list of all documents, newest first, grouped by month.
- Row: type icon (SF Symbol), title, date, small source badge (Shared, Pasted, GitHub, Export).
- `.searchable` over title, text preview and extracted text.
- Swipe actions: Favorite, Delete (with confirmation).
- Context menu: Rename, Share, Delete.
- Toolbar `+` menu: Import files, Paste as document. (Import Claude export is added in Phase 5, the Sync button in Phase 4.)
- Tapping a row opens the document in QuickLook. Better viewers come in Phase 3 (viewers spec).

Phase 2 adds, per the classification spec: category chip on the row, filter chips, Move to category in swipe and context menu, the Images grid.

## Testing

- `FileNaming` and any other pure helpers live in `VaultCore` with Swift Testing tests.
- `DocumentStore`: app-level tests in `VaultTests` against a temporary directory and an in-memory SwiftData container: copy, hash, duplicate detection, delete removes both file and record.
- Device check (Phase 1 acceptance): import a `.md`, a `.pdf`, a `.png` and a `.docx` through S1 or S2; all appear and open; importing the same file twice shows "Already in Vault".
