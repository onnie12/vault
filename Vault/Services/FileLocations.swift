import Foundation

/// Where Vault keeps things on disk.
/// - `filesDirectory`: Application Support/Vault/Files, invisible to the user.
/// - `inboxDirectory`: Documents/Add to Vault, visible in the Files app (source S2).
struct FileLocations: Sendable {
    let filesDirectory: URL
    let inboxDirectory: URL

    /// Not "Inbox": iOS reserves Documents/Inbox on a real iPhone and refuses to let the app
    /// create it (error 513, seen on Onni's iPhone 2026-09-21). The simulator allows it.
    static let inboxFolderName = "Add to Vault"

    static func standard() throws -> FileLocations {
        let fileManager = FileManager.default
        let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask,
                                            appropriateFor: nil, create: true)
        let locations = FileLocations(
            filesDirectory: support.appending(path: "Vault/Files", directoryHint: .isDirectory),
            inboxDirectory: documents.appending(path: inboxFolderName, directoryHint: .isDirectory)
        )
        try locations.createDirectories()
        return locations
    }

    /// A fresh, empty pair of folders under the temp directory. For tests.
    static func temporary() throws -> FileLocations {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VaultTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let locations = FileLocations(
            filesDirectory: root.appending(path: "Files", directoryHint: .isDirectory),
            inboxDirectory: root.appending(path: "Inbox", directoryHint: .isDirectory)
        )
        try locations.createDirectories()
        return locations
    }

    func createDirectories() throws {
        for directory in [filesDirectory, inboxDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func fileURL(forRelativePath relativePath: String) -> URL {
        filesDirectory.appending(path: relativePath, directoryHint: .notDirectory)
    }
}
