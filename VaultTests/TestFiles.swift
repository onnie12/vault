import Foundation

/// Writes throwaway files outside the store, like a file shared from another app.
enum TestFiles {
    static func write(_ name: String, _ contents: String) throws -> URL {
        try write(name, data: Data(contents.utf8))
    }

    static func write(_ name: String, data: Data) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "VaultTestSource-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name, directoryHint: .notDirectory)
        try data.write(to: url)
        return url
    }
}
