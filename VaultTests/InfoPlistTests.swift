import Foundation
import Testing

/// The share sheet (S1) and the Files app inbox (S2) are switched on in Info.plist.
/// Unit tests run inside the app, so `Bundle.main` is the app's own bundle.
@Suite("Info.plist")
struct InfoPlistTests {

    @Test("Files app sharing is on")
    func filesAppSharing() {
        let info = Bundle.main.infoDictionary ?? [:]
        #expect(info["UIFileSharingEnabled"] as? Bool == true)
        #expect(info["LSSupportsOpeningDocumentsInPlace"] as? Bool == true)
    }

    @Test("Vault offers to open the document types from the spec")
    func documentTypes() throws {
        let info = Bundle.main.infoDictionary ?? [:]
        let types = try #require(info["CFBundleDocumentTypes"] as? [[String: Any]])
        let identifiers = types.flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }
        for required in ["public.plain-text", "net.daringfireball.markdown", "public.html", "com.adobe.pdf",
                         "public.image", "public.source-code", "public.json", "public.zip-archive",
                         "org.openxmlformats.wordprocessingml.document",
                         "org.openxmlformats.presentationml.presentation",
                         "org.openxmlformats.spreadsheetml.sheet"] {
            #expect(identifiers.contains(required), "\(required) is missing")
        }
        #expect(types.allSatisfy { $0["LSHandlerRank"] as? String == "Alternate" })
    }
}
