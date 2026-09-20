import SwiftUI
import VaultCore

/// Phase 0 placeholder. Phase 1 replaces this with the real document list.
///
/// A SwiftUI `View` is a value type that describes what the screen should look
/// like, not an object you mutate. `body` is recomputed whenever its inputs change.
struct LibraryPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            Text("Vault")
                .font(.largeTitle.bold())

            Text("Phase 0: the shell builds and runs.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vault. Phase 0: the shell builds and runs.")
    }
}

#Preview {
    LibraryPlaceholderView()
}
