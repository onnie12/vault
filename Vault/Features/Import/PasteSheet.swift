import SwiftUI

/// Source S4. `PasteButton` reads the clipboard only when tapped, so iOS does not
/// show its "Allow Paste" prompt.
struct PasteSheet: View {
    @Environment(ImportController.self) private var controller

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Copy a Claude answer, then tap Paste. It is saved as a Markdown document.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                PasteButton(payloadType: String.self) { strings in
                    let text = strings.joined(separator: "\n\n")
                    // `Task { }` starts async work from a plain closure, like `go func() { }()`.
                    // `@MainActor in` pins it to the main thread, where the controller lives.
                    Task { @MainActor in
                        await controller.importPastedText(text)
                    }
                }
                .labelStyle(.titleAndIcon)
            }
            .padding()
            .navigationTitle("Paste as document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { controller.isPasteSheetPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
