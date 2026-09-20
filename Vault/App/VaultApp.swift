import SwiftUI

// `@main` marks the program entry point, like func main() in Go.
// A SwiftUI App has no main loop you write yourself: you describe the scenes
// and the system runs them.
@main
struct VaultApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryPlaceholderView()
        }
    }
}
