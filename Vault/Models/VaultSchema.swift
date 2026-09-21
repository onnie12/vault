import SwiftData

/// Builds the SwiftData container. `inMemory` is for tests: nothing touches the disk.
enum VaultSchema {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: VaultDocument.self, VaultCategory.self,
            configurations: configuration
        )
    }
}
