import Foundation
import Testing
@testable import Vault

@Suite("FileLocations")
struct FileLocationsTests {

    @Test("The Files app folder is not Documents/Inbox, which iOS reserves on a real iPhone")
    func inboxFolderName() throws {
        let locations = try FileLocations.standard()
        #expect(locations.inboxDirectory.lastPathComponent == "Add to Vault")
        #expect(FileManager.default.fileExists(atPath: locations.inboxDirectory.path(percentEncoded: false)))
    }
}
