import Foundation
import Observation

/// The bridge between SwiftUI and the DocumentStore actor.
///
/// `@MainActor`: everything here runs on the main thread, because views read it.
/// `@Observable`: views that read a property redraw when it changes (a bit like a
/// reactive store in JavaScript). The slow work happens in `DocumentStore`,
/// reached with `await`, so the UI never freezes.
@MainActor
@Observable
final class ImportController {
    let store: DocumentStore
    let locations: FileLocations

    /// Set when an import found the same bytes already stored: the library shows "Already in Vault".
    var duplicateOf: UUID?
    /// A plain-language problem to show, if any.
    var errorMessage: String?
    /// The file QuickLook is showing. Nil means QuickLook is closed.
    var previewURL: URL?
    /// The document open in the built-in text viewer (Markdown, text, code). Nil means closed.
    var textViewerDocumentID: UUID?
    var isPasteSheetPresented = false

    private var isScanningInbox = false

    init(store: DocumentStore, locations: FileLocations) {
        self.store = store
        self.locations = locations
    }

    /// Files from the share sheet (S1) or the file picker (S3). Both hand over
    /// security-scoped URLs: access must be requested before reading and released after.
    func importFiles(_ urls: [URL], source: DocumentSource) async {
        for url in urls {
            let granted = url.startAccessingSecurityScopedResource()
            // `defer` runs when this loop iteration ends, like Go's defer at function end.
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            do {
                if case .alreadyInVault(let id) = try await store.importFile(at: url, source: source) {
                    duplicateOf = id
                }
            } catch {
                errorMessage = "Could not import \(url.lastPathComponent). \(error.localizedDescription)"
            }
        }
    }

    func importPastedText(_ text: String) async {
        do {
            if case .alreadyInVault(let id) = try await store.importPastedText(text) {
                duplicateOf = id
            }
            isPasteSheetPresented = false
        } catch {
            errorMessage = "Could not save the pasted text. \(error.localizedDescription)"
        }
    }

    func delete(_ id: UUID) async {
        do { try await store.delete(id) } catch {
            errorMessage = "Could not delete the document. \(error.localizedDescription)"
        }
    }

    func rename(_ id: UUID, to title: String) async {
        do { try await store.rename(id, to: title) } catch {
            errorMessage = "Could not rename the document. \(error.localizedDescription)"
        }
    }

    func setFavorite(_ id: UUID, _ isFavorite: Bool) async {
        do { try await store.setFavorite(id, isFavorite) } catch {
            errorMessage = "Could not change the favorite. \(error.localizedDescription)"
        }
    }

    /// Opens a document: Markdown, text and code in the text viewer, everything else in QuickLook.
    func open(_ id: UUID, contentTypeIdentifier: String, storedRelativePath: String) {
        if TextViewerMode(contentTypeIdentifier: contentTypeIdentifier) != nil {
            textViewerDocumentID = id
        } else {
            previewURL = locations.fileURL(forRelativePath: storedRelativePath)
        }
    }

    /// Opens the document that a duplicate import pointed at.
    func openExisting(_ id: UUID) async {
        guard let snapshot = try? await store.snapshot(of: id) else { return }
        open(id, contentTypeIdentifier: snapshot.contentTypeIdentifier,
             storedRelativePath: snapshot.storedRelativePath)
    }

    /// Source S2. Runs whenever the app becomes active; overlapping calls are ignored.
    func scanInbox() async {
        guard !isScanningInbox else { return }
        isScanningInbox = true
        defer { isScanningInbox = false }

        let summary = await InboxScanner(inboxDirectory: locations.inboxDirectory, store: store).scan()
        if summary.failed > 0 {
            errorMessage = "\(summary.failed) file(s) in the Vault inbox could not be imported. They are still in the inbox."
        }
    }

    func fileURL(for document: VaultDocument) -> URL {
        locations.fileURL(forRelativePath: document.storedRelativePath)
    }
}
