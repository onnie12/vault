import Foundation
import Testing
@testable import VaultCore

@Suite("ContentHash")
struct ContentHashTests {

    @Test("Matches the published SHA-256 test vectors")
    func knownVectors() {
        #expect(ContentHash.sha256Hex(of: Data())
                == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(ContentHash.sha256Hex(of: Data("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("Same bytes, same hash; one byte different, different hash")
    func detectsDuplicates() {
        let a = ContentHash.sha256Hex(of: Data("M319 Lernziele".utf8))
        let b = ContentHash.sha256Hex(of: Data("M319 Lernziele".utf8))
        let c = ContentHash.sha256Hex(of: Data("M319 Lernziele!".utf8))
        #expect(a == b)
        #expect(a != c)
    }
}
