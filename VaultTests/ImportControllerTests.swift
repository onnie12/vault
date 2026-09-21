import Foundation
import Testing
@testable import Vault

@MainActor
@Suite("ImportController")
struct ImportControllerTests {
    let locations: FileLocations
    let controller: ImportController

    init() throws {
        locations = try FileLocations.temporary()
        let store = DocumentStore(modelContainer: try VaultSchema.makeContainer(inMemory: true), locations: locations)
        controller = ImportController(store: store, locations: locations)
    }

    @Test("A duplicate sets the Already in Vault notice, a new file does not")
    func duplicateNotice() async throws {
        await controller.importFiles([try TestFiles.write("a.md", "same")], source: .picker)
        #expect(controller.duplicateOf == nil)

        await controller.importFiles([try TestFiles.write("b.md", "same")], source: .picker)
        #expect(controller.duplicateOf != nil)
    }

    @Test("A failed import explains itself and names the file")
    func errorMessage() async {
        await controller.importFiles([URL(filePath: "/does/not/exist/x.md")], source: .picker)
        #expect(controller.errorMessage?.contains("x.md") == true)
    }

    @Test("Pasting closes the paste sheet")
    func pasteClosesSheet() async {
        controller.isPasteSheetPresented = true
        await controller.importPastedText("# Hi")
        #expect(controller.isPasteSheetPresented == false)
        #expect(controller.errorMessage == nil)
    }

    @Test("Opening an existing document points QuickLook at its stored file")
    func openExisting() async throws {
        await controller.importFiles([try TestFiles.write("a.md", "same")], source: .picker)
        await controller.importFiles([try TestFiles.write("b.md", "same")], source: .picker)
        let id = try #require(controller.duplicateOf)

        await controller.openExisting(id)

        let url = try #require(controller.previewURL)
        #expect(url.lastPathComponent == "a.md")
        #expect(url.path(percentEncoded: false).hasPrefix(locations.filesDirectory.path(percentEncoded: false)))
    }
}
