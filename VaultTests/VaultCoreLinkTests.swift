import Testing
import VaultCore
@testable import Vault

/// Phase 0 has one job on the app side: prove the target builds, that the local
/// VaultCore package is actually linked in, and that the test scheme runs in the
/// simulator. Real app tests arrive with the DocumentStore in Phase 1.
@Suite("Vault app")
struct VaultCoreLinkTests {

    @Test("VaultCore is linked into the app target")
    func coreIsLinked() {
        #expect(FileNaming.sanitize("m319-zusammenfassung.md") == "m319-zusammenfassung.md")
    }
}
