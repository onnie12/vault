import Foundation
import Testing
@testable import Vault

@Suite("InboxScanner")
struct InboxScannerTests {
    let locations: FileLocations
    let store: DocumentStore
    let scanner: InboxScanner

    init() throws {
        locations = try FileLocations.temporary()
        store = DocumentStore(modelContainer: try VaultSchema.makeContainer(inMemory: true), locations: locations)
        scanner = InboxScanner(inboxDirectory: locations.inboxDirectory, store: store)
    }

    func put(_ name: String, _ contents: String) throws -> URL {
        let url = locations.inboxDirectory.appending(path: name, directoryHint: .notDirectory)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    @Test("Imports every file, then removes the originals")
    func importsAndRemoves() async throws {
        let a = try put("fix-grub.md", "sudo grub-install")
        let b = try put("notes.txt", "Subnetting")

        let summary = await scanner.scan()

        #expect(summary == InboxScanner.Summary(imported: 2, alreadyInVault: 0, failed: 0))
        #expect(!exists(a))
        #expect(!exists(b))
        #expect(try await store.allSnapshots().map(\.sourceRaw) == ["inbox", "inbox"])
    }

    @Test("A duplicate is removed from the inbox too, its content is already safe")
    func duplicateIsRemoved() async throws {
        _ = try await store.importFile(at: try TestFiles.write("orig.md", "same"), source: .shared)
        let copy = try put("copy.md", "same")

        let summary = await scanner.scan()

        #expect(summary == InboxScanner.Summary(imported: 0, alreadyInVault: 1, failed: 0))
        #expect(!exists(copy))
    }

    @Test("Hidden files and folders are left alone")
    func skipsHiddenAndFolders() async throws {
        let hidden = try put(".DS_Store", "junk")
        let folder = locations.inboxDirectory.appending(path: "Sub", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let summary = await scanner.scan()

        #expect(summary == InboxScanner.Summary(imported: 0, alreadyInVault: 0, failed: 0))
        #expect(exists(hidden))
        #expect(exists(folder))
    }

    @Test("A missing inbox folder is not an error")
    func missingInbox() async throws {
        try FileManager.default.removeItem(at: locations.inboxDirectory)
        #expect(await scanner.scan() == InboxScanner.Summary(imported: 0, alreadyInVault: 0, failed: 0))
    }
}
