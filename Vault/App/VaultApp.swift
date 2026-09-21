import SwiftData
import SwiftUI

// `@main` marks the program entry point, like func main() in Go.
// A SwiftUI App has no main loop you write yourself: you describe the scenes
// and the system runs them.
@main
struct VaultApp: App {
    private let container: ModelContainer
    @State private var controller: ImportController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let locations = try FileLocations.standard()
            let container = try VaultSchema.makeContainer()
            let store = DocumentStore(modelContainer: container, locations: locations)
            self.container = container
            _controller = State(initialValue: ImportController(store: store, locations: locations))
        } catch {
            // Without its storage Vault can do nothing useful. A friendlier screen
            // for this case is Phase 6 polish.
            fatalError("Vault could not open its storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(controller)
                // Source S1: "Open in Vault" from any app's share sheet lands here.
                .onOpenURL { url in
                    Task { await controller.importFiles([url], source: .shared) }
                }
        }
        .modelContainer(container)
        // Source S2: import the Files app inbox on launch and whenever Vault comes back.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await controller.scanInbox() }
            }
        }
    }
}
