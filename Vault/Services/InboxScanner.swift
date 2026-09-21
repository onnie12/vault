import Foundation

/// Source S2: imports everything Onni saved into Documents/Inbox through the Files app.
/// An original is removed only after its content is safely in Vault (imported now,
/// or already there). Hidden files and sub-folders are skipped.
struct InboxScanner: Sendable {
    let inboxDirectory: URL
    let store: DocumentStore

    struct Summary: Sendable, Equatable {
        var imported = 0
        var alreadyInVault = 0
        var failed = 0
    }

    func scan() async -> Summary {
        var summary = Summary()
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: inboxDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return summary
        }

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isRegularFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            guard isRegularFile else { continue }
            do {
                switch try await store.importFile(at: url, source: .inbox) {
                case .imported: summary.imported += 1
                case .alreadyInVault: summary.alreadyInVault += 1
                }
                try fileManager.removeItem(at: url)
            } catch {
                // Left in the inbox; the next scan tries again.
                summary.failed += 1
            }
        }
        return summary
    }
}
