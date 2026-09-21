import QuickLook
import SwiftData
import SwiftUI
import VaultCore

/// The main screen: every document, newest first, grouped by month, searchable.
struct LibraryView: View {
    @Environment(ImportController.self) private var controller

    // `@Query` fetches from SwiftData and keeps the array up to date as the store changes.
    @Query(sort: \VaultDocument.createdAt, order: .reverse) private var documents: [VaultDocument]

    // `@State` is view-local memory that survives redraws.
    @State private var searchText = ""
    @State private var isFileImporterPresented = false
    @State private var pendingDelete: VaultDocument?
    @State private var renaming: VaultDocument?
    @State private var renameText = ""

    private var filtered: [VaultDocument] {
        documents.filter {
            LibrarySearch.matches(searchText, fields: [$0.title, $0.textPreview, $0.searchText])
        }
    }

    var body: some View {
        // `@Bindable` lets us hand out two-way bindings ($) to the controller's properties.
        @Bindable var controller = controller

        NavigationStack {
            List {
                ForEach(LibraryGrouping.byMonth(filtered, calendar: .current, date: \.createdAt)) { group in
                    Section(monthTitle(year: group.year, month: group.month)) {
                        ForEach(group.items) { document in
                            row(for: document)
                        }
                    }
                }
            }
            .overlay { emptyState }
            .navigationTitle("Vault")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Import files", systemImage: "folder") { isFileImporterPresented = true }
                        Button("Paste as document", systemImage: "doc.on.clipboard") {
                            controller.isPasteSheetPresented = true
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.item],
                          allowsMultipleSelection: true) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let urls):
                        await controller.importFiles(urls, source: .picker)
                    case .failure(let error):
                        controller.errorMessage = "Could not open the file picker. \(error.localizedDescription)"
                    }
                }
            }
            .sheet(isPresented: $controller.isPasteSheetPresented) {
                PasteSheet()
            }
            .confirmationDialog(
                "Delete this document?",
                isPresented: isPresent($pendingDelete),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { document in
                let id = document.id
                Button("Delete", role: .destructive) {
                    Task { await controller.delete(id) }
                }
            } message: { document in
                Text("\"\(document.title)\" will be removed from Vault. This cannot be undone.")
            }
            .alert("Rename", isPresented: isPresent($renaming), presenting: renaming) { document in
                let id = document.id
                TextField("Title", text: $renameText)
                Button("Save") {
                    let title = renameText
                    Task { await controller.rename(id, to: title) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Already in Vault", isPresented: isPresent($controller.duplicateOf),
                   presenting: controller.duplicateOf) { id in
                Button("Open") { Task { await controller.openExisting(id) } }
                Button("OK", role: .cancel) {}
            } message: { _ in
                Text("This file is already in Vault.")
            }
            .alert("Something went wrong", isPresented: isPresent($controller.errorMessage),
                   presenting: controller.errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .quickLookPreview($controller.previewURL)
            .navigationDestination(item: $controller.textViewerDocumentID) { id in
                textViewer(for: id)
            }
        }
    }

    // MARK: - Pieces

    private func row(for document: VaultDocument) -> some View {
        let id = document.id
        let fileURL = controller.fileURL(for: document)
        return Button {
            controller.open(id, contentTypeIdentifier: document.contentTypeIdentifier,
                            storedRelativePath: document.storedRelativePath)
        } label: {
            DocumentRow(document: document)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            let isFavorite = document.isFavorite
            Button(isFavorite ? "Unfavorite" : "Favorite",
                   systemImage: isFavorite ? "star.slash" : "star") {
                Task { await controller.setFavorite(id, !isFavorite) }
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                pendingDelete = document
            }
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                renameText = document.title
                renaming = document
            }
            ShareLink(item: fileURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                pendingDelete = document
            }
        }
    }

    @ViewBuilder
    private func textViewer(for id: UUID) -> some View {
        if let document = documents.first(where: { $0.id == id }),
           let mode = TextViewerMode(contentTypeIdentifier: document.contentTypeIdentifier) {
            TextDocumentView(title: document.title, fileURL: controller.fileURL(for: document), mode: mode)
        } else {
            ContentUnavailableView("Document not found", systemImage: "questionmark.folder")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if documents.isEmpty {
            ContentUnavailableView(
                "No documents yet",
                systemImage: "tray",
                description: Text("Tap + to import a file or paste text. You can also save files to On My iPhone > Vault > Inbox in the Files app.")
            )
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private func monthTitle(year: Int, month: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? .now
        return date.formatted(.dateTime.month(.wide).year())
    }

    /// Turns "an optional is set" into the Bool binding that alerts and dialogs want.
    private func isPresent<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }
}
