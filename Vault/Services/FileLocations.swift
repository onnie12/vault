import Foundation

/// Where Vault keeps things on disk.
/// - `filesDirectory`: Application Support/Vault/Files, invisible to the user.
/// - `inboxDirectory`: Documents/Inbox, visible in the Files app (source S2).
struct FileLocations: Sendable {
    let filesDirectory: URL
    let inboxDirectory: URL

    static func standard() throws -> FileLocations {
        let fileManager = FileManager.default
        let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask,
                                            appropriateFor: nil, create: true)
        let locations = FileLocations(
            filesDirectory: support.appending(path: "Vault/Files", directoryHint: .isDirectory),
            inboxDirectory: documents.appending(path: "Inbox", directoryHint: .isDirectory)
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
