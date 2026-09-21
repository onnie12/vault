import SwiftUI

/// Full-screen viewer for Markdown, plain text and code files.
struct TextDocumentView: View {
    let title: String
    let fileURL: URL
    let mode: TextViewerMode

    // Loading state. `enum` with associated values is like a Go interface with
    // one struct per case, but the compiler checks every case is handled.
    private enum Phase {
        case loading
        case loaded(TextRenderPayload)
        case failed(String)
    }

    @State private var phase = Phase.loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
            case .loaded(let payload):
                RenderedTextView(payload: payload)
                    .ignoresSafeArea(edges: .bottom)
            case .failed(let message):
                ContentUnavailableView("Cannot show this document",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(message))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: fileURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        // `.task` starts when the view appears and is cancelled when it goes away.
        .task {
            do {
                phase = .loaded(try await TextRenderPayload.load(fileURL: fileURL, mode: mode))
            } catch {
                phase = .failed("The file could not be read as text. \(error.localizedDescription)")
            }
        }
    }
}
