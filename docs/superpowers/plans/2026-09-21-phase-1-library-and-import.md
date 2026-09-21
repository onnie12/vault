# Phase 1: Library, Storage and Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Onni can get documents into Vault four ways (share sheet, Files inbox, file picker, paste), they are stored once on disk with metadata in SwiftData, and he sees them in one searchable list that opens each file in QuickLook.

**Architecture:** Pure logic (titles, text snippets, hashing, month grouping, search matching) goes into the `VaultCore` package so it tests on Linux. The app gets two SwiftData models, a `DocumentStore` actor that owns every write (copy, hash, de-duplicate, delete), an `InboxScanner`, and a main-actor `ImportController` that connects SwiftUI to the store. Views read with `@Query` and never write to SwiftData directly.

**Tech Stack:** Swift 6.4, Swift 6 language mode, SwiftUI, SwiftData, PDFKit (text extraction), QuickLook, UniformTypeIdentifiers, `apple/swift-crypto` (SHA-256), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-21-library-and-import-design.md`

## Global Constraints

- Deployment target iOS 27.0, iPhone only. Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY: complete` (already in `project.yml`).
- `VaultCore` imports Foundation and `Crypto` only. No SwiftUI, SwiftData, UIKit, UniformTypeIdentifiers, PDFKit or WebKit in `VaultCore`.
- Dependencies: only `apple/swift-crypto` is added in this phase, range `"4.0.0" ..< "6.0.0"` (5.0.0 is latest, released 2026-09-16, needs Swift 6.2). Nothing else without asking Onni.
- No capability that needs the paid Apple Developer Program. No App Groups, no extensions.
- Never store file contents in SwiftData. Files live at `Application Support/Vault/Files/<document-uuid>/<sanitized-file-name>`.
- File I/O, hashing and text extraction run off the main actor. `@Model` objects never cross actors: pass `UUID`s or `Sendable` structs.
- Never delete a user document automatically. The only automatic removal is an original in `Documents/Inbox/` after its content is safely in Vault.
- UI text in English. No em-dashes anywhere (code, comments, commit messages).
- Onni knows Go and JavaScript, no Swift: comment the first use of each Swift concept briefly, with the Go equivalent where there is one.
- Every commit message ends with the attribution line `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## How to run the tests

There is no Mac and (so far) no Swift toolchain on Onni's machine. GitHub CI is the compiler.

- **VaultCore tests, local** (only if a Swift 6.2+ toolchain is installed): `swift test --package-path VaultCore --filter <SuiteName>`
- **Everything, CI:** push, then

  ```bash
  git push
  gh run watch "$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
  ```

  On failure: `gh run view --log-failed`. To prove new tests actually ran (a green run with zero tests is not a pass): `gh run view <run-id> --log | grep -E '✔ Test|✘ Test|Test run with'`.
- **The TDD red step:** do it locally when a toolchain exists. On CI only, skip pushing the failing test on its own (it costs a full round trip of about 4 minutes) and instead check in the green run that the new test names appear in the log.

## File structure

| File | Responsibility |
|---|---|
| `VaultCore/Package.swift` | Add the swift-crypto dependency |
| `VaultCore/Sources/VaultCore/DocumentTitle.swift` | Title for pasted text and for imported files |
| `VaultCore/Sources/VaultCore/TextSnippets.swift` | Decode text bytes, strip HTML, row preview, search text |
| `VaultCore/Sources/VaultCore/ContentHash.swift` | SHA-256 hex for de-duplication |
| `VaultCore/Sources/VaultCore/LibraryGrouping.swift` | Group a newest-first list by month |
| `VaultCore/Sources/VaultCore/LibrarySearch.swift` | Does a document match a search query |
| `Vault/Models/VaultDocument.swift` | SwiftData model, from the spec |
| `Vault/Models/VaultCategory.swift` | SwiftData model, from the spec (used from Phase 2) |
| `Vault/Models/DocumentSource.swift` | The `sourceRaw` values and their badge text |
| `Vault/Models/DocumentKind.swift` | SF Symbol per content type |
| `Vault/Models/VaultSchema.swift` | Builds the `ModelContainer` |
| `Vault/Services/FileLocations.swift` | Where files and the inbox live |
| `Vault/Services/TextExtractor.swift` | Text out of text files, HTML and PDFs |
| `Vault/Services/DocumentStore.swift` | The only writer: import, paste, delete, rename, favorite |
| `Vault/Services/InboxScanner.swift` | Source S2 |
| `Vault/Features/Import/ImportController.swift` | Main-actor bridge between views and the store |
| `Vault/Features/Import/PasteSheet.swift` | Source S4 UI |
| `Vault/Features/Library/LibraryView.swift` | The main screen |
| `Vault/Features/Library/DocumentRow.swift` | One row |
| `Vault/App/VaultApp.swift` | Wiring: container, controller, `onOpenURL`, inbox scan |
| `Vault/Info.plist` | Markdown type declaration, document types, Files app sharing |
| `VaultTests/TestFiles.swift` | Helper that writes throwaway source files |
| `VaultTests/*Tests.swift` | App-level tests, one file per unit |

`Vault/Features/Library/LibraryPlaceholderView.swift` is deleted in Task 10.

---

### Task 1: DocumentTitle (VaultCore)

**Files:**
- Create: `VaultCore/Sources/VaultCore/DocumentTitle.swift`
- Test: `VaultCore/Tests/VaultCoreTests/DocumentTitleTests.swift`

**Interfaces:**
- Consumes: `FileNaming.fileExtension(of:)` (exists)
- Produces: `DocumentTitle.forPastedText(_ text: String) -> String`, `DocumentTitle.forFileName(_ fileName: String) -> String`, `DocumentTitle.maxLength: Int` (80), `DocumentTitle.fallback: String` ("Pasted document")

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
@testable import VaultCore

@Suite("DocumentTitle")
struct DocumentTitleTests {

    @Test("Pasted text: the first Markdown heading wins")
    func headingWins() {
        #expect(DocumentTitle.forPastedText("# M319 Lernziele\n\nText") == "M319 Lernziele")
        #expect(DocumentTitle.forPastedText("Intro line\n## Subnetting\nmore") == "Subnetting")
    }

    @Test("Pasted text: without a heading, the first non-empty line")
    func firstLineFallback() {
        #expect(DocumentTitle.forPastedText("Milch, Brot\nEier") == "Milch, Brot")
        #expect(DocumentTitle.forPastedText("\n\n   Hello  \n") == "Hello")
    }

    @Test("A hashtag is not a heading, a closing ## is not part of the title")
    func headingSyntax() {
        #expect(DocumentTitle.forPastedText("#todo buy milk") == "#todo buy milk")
        #expect(DocumentTitle.forPastedText("## Title ##") == "Title")
        #expect(DocumentTitle.forPastedText("## Learning C#") == "Learning C#")
    }

    @Test("Pasted text: cut to 80 characters, fallback when empty")
    func lengthAndFallback() {
        let long = String(repeating: "a", count: 200)
        #expect(DocumentTitle.forPastedText(long) == String(repeating: "a", count: 80))
        #expect(DocumentTitle.forPastedText("  \n \n") == "Pasted document")
    }

    @Test("File name: drop the extension, keep names that have none")
    func fromFileName() {
        #expect(DocumentTitle.forFileName("m319-zusammenfassung.md") == "m319-zusammenfassung")
        #expect(DocumentTitle.forFileName("Makefile") == "Makefile")
        #expect(DocumentTitle.forFileName("Notizen vom 20.09") == "Notizen vom 20.09")
    }
}
```

- [ ] **Step 2: Run to verify they fail** (local toolchain only)

Run: `swift test --package-path VaultCore --filter DocumentTitleTests`
Expected: build error `cannot find 'DocumentTitle' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Picks a human-readable title for a new document.
public enum DocumentTitle {

    public static let maxLength = 80
    public static let fallback = "Pasted document"

    /// Title for text pasted from the clipboard (source S4): the first Markdown
    /// heading, else the first non-empty line, cut to `maxLength` characters.
    public static func forPastedText(_ text: String) -> String {
        // `split` returns Substrings (views into the original, like a Go slice of a string).
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let candidate = lines.lazy.compactMap { headingText($0) }.first ?? lines.first ?? ""
        let title = String(candidate.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? fallback : title
    }

    /// Title for an imported file: its name without the extension.
    public static func forFileName(_ fileName: String) -> String {
        let ext = FileNaming.fileExtension(of: fileName)
        let base = ext.isEmpty ? fileName : String(fileName.dropLast(ext.count + 1))
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fileName : trimmed
    }

    /// "## Lernziele" -> "Lernziele". Nil when the line is not an ATX heading.
    static func headingText(_ line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        // A closing sequence like "## Title ##" is Markdown syntax, not part of the title.
        let withoutClosing = text.replacingOccurrences(of: #"\s+#+$"#, with: "", options: .regularExpression)
        return withoutClosing.isEmpty ? nil : withoutClosing
    }
}
```

- [ ] **Step 4: Run to verify they pass**

Local: `swift test --package-path VaultCore --filter DocumentTitleTests`, expected 5 tests pass. Or CI (see "How to run the tests"), expected `✔ Suite "DocumentTitle" passed` in the log.

- [ ] **Step 5: Commit**

```bash
git add VaultCore/Sources/VaultCore/DocumentTitle.swift VaultCore/Tests/VaultCoreTests/DocumentTitleTests.swift
git commit -m "Add DocumentTitle for pasted text and imported files

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: TextSnippets (VaultCore)

**Files:**
- Create: `VaultCore/Sources/VaultCore/TextSnippets.swift`
- Test: `VaultCore/Tests/VaultCoreTests/TextSnippetsTests.swift`

**Interfaces:**
- Produces: `TextSnippets.decodeText(_ data: Data) -> String?`, `TextSnippets.plainText(fromHTML html: String) -> String`, `TextSnippets.preview(of text: String) -> String`, `TextSnippets.searchText(of text: String) -> String?`, constants `previewLength` (500) and `searchLength` (50_000)

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import VaultCore

@Suite("TextSnippets")
struct TextSnippetsTests {

    @Test("Preview collapses whitespace into single spaces")
    func previewCollapsesWhitespace() {
        #expect(TextSnippets.preview(of: "# Title\n\n  Some   text\n") == "# Title Some text")
        #expect(TextSnippets.preview(of: " \n\t ") == "")
    }

    @Test("Preview stops at 500 characters")
    func previewLimit() {
        let preview = TextSnippets.preview(of: String(repeating: "a", count: 600))
        #expect(preview.count == 500)
    }

    @Test("Search text keeps the first 50,000 characters, nil when blank")
    func searchText() {
        let long = String(repeating: "b", count: 60_000)
        #expect(TextSnippets.searchText(of: long)?.count == 50_000)
        #expect(TextSnippets.searchText(of: "  \n ") == nil)
    }

    @Test("Decodes UTF-8 and drops a byte order mark")
    func decodesUTF8() {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("Prüfung".utf8)
        #expect(TextSnippets.decodeText(data) == "Prüfung")
    }

    @Test("Decodes UTF-16 little endian with a byte order mark")
    func decodesUTF16() {
        var bytes: [UInt8] = [0xFF, 0xFE]
        for unit in "Hallo".utf16 {
            bytes.append(UInt8(unit & 0xFF))
            bytes.append(UInt8(unit >> 8))
        }
        #expect(TextSnippets.decodeText(Data(bytes)) == "Hallo")
    }

    @Test("Falls back to Windows-1252 for old Windows text files")
    func decodesWindows1252() throws {
        let data = try #require("Prüfung".data(using: .windowsCP1252))
        #expect(TextSnippets.decodeText(data) == "Prüfung")
    }

    @Test("HTML: tags, scripts and styles removed")
    func stripsHTML() {
        let html = "<html><head><style>p{color:red}</style></head><body><h1>Hallo</h1><script>x()</script><p>Welt</p></body></html>"
        #expect(TextSnippets.preview(of: TextSnippets.plainText(fromHTML: html)) == "Hallo Welt")
    }
}
```

- [ ] **Step 2: Run to verify they fail** (local only)

Run: `swift test --package-path VaultCore --filter TextSnippetsTests`
Expected: build error `cannot find 'TextSnippets' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Turns file contents into the two text fields a document row and search need.
public enum TextSnippets {

    public static let previewLength = 500
    public static let searchLength = 50_000

    /// Bytes to text: UTF-8 (with or without BOM), UTF-16 with BOM, else Windows-1252.
    /// Returns nil only when nothing fits.
    public static func decodeText(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(2))
        if bytes == [0xFF, 0xFE] {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if bytes == [0xFE, 0xFF] {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        if let text = String(data: data, encoding: .utf8) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        return String(data: data, encoding: .windowsCP1252)
    }

    /// Rough HTML to text for previews and search. Not a renderer: entities stay as they are.
    public static func plainText(fromHTML html: String) -> String {
        html
            .replacingOccurrences(of: #"(?is)<(script|style)\b.*?</\1>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    }

    /// Short one-paragraph preview for list rows: whitespace runs become one space.
    public static func preview(of text: String) -> String {
        var result = ""
        result.reserveCapacity(previewLength)
        var count = 0
        var pendingSpace = false

        for character in text {
            if character.isWhitespace {
                pendingSpace = count > 0
                continue
            }
            if pendingSpace {
                guard count < previewLength else { break }
                result.append(" ")
                count += 1
                pendingSpace = false
            }
            guard count < previewLength else { break }
            result.append(character)
            count += 1
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// The part of the text that gets indexed for search, or nil when there is nothing to index.
    public static func searchText(of text: String) -> String? {
        let prefix = String(text.prefix(searchLength))
        return prefix.allSatisfy(\.isWhitespace) ? nil : prefix
    }
}
```

- [ ] **Step 4: Run to verify they pass**

Local: `swift test --package-path VaultCore --filter TextSnippetsTests`, expected 7 pass. Or CI, expected `✔ Suite "TextSnippets" passed`.

- [ ] **Step 5: Commit**

```bash
git add VaultCore/Sources/VaultCore/TextSnippets.swift VaultCore/Tests/VaultCoreTests/TextSnippetsTests.swift
git commit -m "Add TextSnippets: decode text, strip HTML, preview and search text

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: ContentHash and the swift-crypto dependency (VaultCore)

**Files:**
- Modify: `VaultCore/Package.swift`
- Create: `VaultCore/Sources/VaultCore/ContentHash.swift`
- Test: `VaultCore/Tests/VaultCoreTests/ContentHashTests.swift`

**Interfaces:**
- Produces: `ContentHash.sha256Hex(of data: Data) -> String` (64 lowercase hex characters)

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run to verify they fail** (local only)

Run: `swift test --package-path VaultCore --filter ContentHashTests`
Expected: build error `cannot find 'ContentHash' in scope`.

- [ ] **Step 3: Add the dependency.** Replace `VaultCore/Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

// VaultCore holds every piece of logic that does not need Apple frameworks:
// the classifier, the front matter parser, the Claude export reader, the GitHub
// diff and file naming. Foundation only (plus swift-crypto), so `swift test`
// also works on Linux.
//
// No `platforms:` block on purpose. Declaring .iOS(.v27) would stop the manifest
// from even parsing on an older Swift toolchain on Linux. The app target sets the
// real deployment target, and nothing here depends on a recent iOS version.
let package = Package(
    name: "VaultCore",
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"])
    ],
    dependencies: [
        // SHA-256 for de-duplication. On Apple platforms it forwards to CryptoKit,
        // on Linux it ships its own implementation. 5.x needs Swift 6.2; the range
        // lets an older local toolchain fall back to 4.x.
        .package(url: "https://github.com/apple/swift-crypto.git", "4.0.0" ..< "6.0.0")
    ],
    targets: [
        .target(
            name: "VaultCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
```

- [ ] **Step 4: Implement**

```swift
import Crypto
import Foundation

/// SHA-256 fingerprints for file contents. Two files with the same bytes get the
/// same hash, which is how Vault spots duplicates (spec: "Already in Vault").
public enum ContentHash {

    /// Lowercase hex SHA-256 of `data`, 64 characters.
    public static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
```

- [ ] **Step 5: Run to verify they pass**

Local: `swift test --package-path VaultCore --filter ContentHashTests`, expected 2 pass (first run downloads swift-crypto). Or CI, expected `✔ Suite "ContentHash" passed`. Also check in the CI log that the **App tests** step still passes: the app now links swift-crypto through VaultCore.

- [ ] **Step 6: Commit**

```bash
git add VaultCore/Package.swift VaultCore/Sources/VaultCore/ContentHash.swift VaultCore/Tests/VaultCoreTests/ContentHashTests.swift
git commit -m "Add ContentHash (SHA-256) using swift-crypto

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

If `swift test` created `VaultCore/Package.resolved`, commit it in the same commit so CI and local resolve the same version.

---

### Task 4: LibraryGrouping and LibrarySearch (VaultCore)

**Files:**
- Create: `VaultCore/Sources/VaultCore/LibraryGrouping.swift`
- Create: `VaultCore/Sources/VaultCore/LibrarySearch.swift`
- Test: `VaultCore/Tests/VaultCoreTests/LibraryGroupingTests.swift`
- Test: `VaultCore/Tests/VaultCoreTests/LibrarySearchTests.swift`

**Interfaces:**
- Produces: `struct MonthGroup<Item>: Identifiable` with `year: Int`, `month: Int`, `items: [Item]`, `id: Int` (`year * 100 + month`); `LibraryGrouping.byMonth<Item>(_ items: [Item], calendar: Calendar, date: (Item) -> Date) -> [MonthGroup<Item>]`; `LibrarySearch.matches(_ query: String, fields: [String?]) -> Bool`

- [ ] **Step 1: Write the failing tests**

`LibraryGroupingTests.swift`:

```swift
import Foundation
import Testing
@testable import VaultCore

@Suite("LibraryGrouping")
struct LibraryGroupingTests {

    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Groups a newest-first list by month and keeps the order")
    func groupsByMonth() {
        let dates = [day(2026, 9, 20), day(2026, 9, 1), day(2026, 8, 31), day(2025, 9, 15)]
        let groups = LibraryGrouping.byMonth(dates, calendar: calendar, date: { $0 })

        #expect(groups.map(\.year) == [2026, 2026, 2025])
        #expect(groups.map(\.month) == [9, 8, 9])
        #expect(groups.map(\.items.count) == [2, 1, 1])
        #expect(groups[0].items == [day(2026, 9, 20), day(2026, 9, 1)])
        #expect(groups.map(\.id) == [202609, 202608, 202509])
    }

    @Test("An empty list gives no groups")
    func emptyList() {
        #expect(LibraryGrouping.byMonth([Date](), calendar: calendar, date: { $0 }).isEmpty)
    }
}
```

`LibrarySearchTests.swift`:

```swift
import Testing
@testable import VaultCore

@Suite("LibrarySearch")
struct LibrarySearchTests {

    @Test("An empty query matches everything")
    func emptyQuery() {
        #expect(LibrarySearch.matches("", fields: ["anything"]))
        #expect(LibrarySearch.matches("   ", fields: [nil]))
    }

    @Test("Ignores case and diacritics")
    func caseAndDiacritics() {
        #expect(LibrarySearch.matches("m319", fields: ["M319 Lernziele"]))
        #expect(LibrarySearch.matches("prufung", fields: ["M122 Prüfung"]))
    }

    @Test("Every word must appear, in any field")
    func allWords() {
        let fields: [String?] = ["fix-grub", nil, "sudo grub-install on CachyOS"]
        #expect(LibrarySearch.matches("grub cachyos", fields: fields))
        #expect(!LibrarySearch.matches("grub fedora", fields: fields))
    }
}
```

- [ ] **Step 2: Run to verify they fail** (local only)

Run: `swift test --package-path VaultCore --filter "LibraryGroupingTests|LibrarySearchTests"`
Expected: build errors `cannot find 'LibraryGrouping'` and `cannot find 'LibrarySearch'`.

- [ ] **Step 3: Implement**

`LibraryGrouping.swift`:

```swift
import Foundation

/// One month section of the library list.
/// `<Item>` is a generic type parameter, the same idea as Go's `[T any]`.
public struct MonthGroup<Item>: Identifiable {
    public let year: Int
    public let month: Int
    public var items: [Item]

    /// Stable id for SwiftUI's ForEach, for example 202609.
    public var id: Int { year * 100 + month }
}

// Conditional conformance: MonthGroup is Sendable/Equatable only when its items are.
extension MonthGroup: Sendable where Item: Sendable {}
extension MonthGroup: Equatable where Item: Equatable {}

public enum LibraryGrouping {

    /// Groups items by calendar month, keeping their order. Expects `items`
    /// sorted newest first, which is how the library lists them.
    public static func byMonth<Item>(
        _ items: [Item],
        calendar: Calendar,
        date: (Item) -> Date
    ) -> [MonthGroup<Item>] {
        var groups: [MonthGroup<Item>] = []
        for item in items {
            let parts = calendar.dateComponents([.year, .month], from: date(item))
            let year = parts.year ?? 0
            let month = parts.month ?? 0
            if let last = groups.last, last.year == year, last.month == month {
                groups[groups.count - 1].items.append(item)
            } else {
                groups.append(MonthGroup(year: year, month: month, items: [item]))
            }
        }
        return groups
    }
}
```

`LibrarySearch.swift`:

```swift
import Foundation

public enum LibrarySearch {

    /// True when every word of `query` appears in at least one of `fields`,
    /// ignoring case and diacritics ("prufung" finds "Prüfung"). Nil fields are skipped.
    public static func matches(_ query: String, fields: [String?]) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = fields.compactMap { $0 }.joined(separator: "\n")
        return words.allSatisfy { word in
            haystack.range(of: String(word), options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
```

- [ ] **Step 4: Run to verify they pass**

Local: `swift test --package-path VaultCore --filter "LibraryGroupingTests|LibrarySearchTests"`, expected 5 pass. Or CI.

- [ ] **Step 5: Commit**

```bash
git add VaultCore/Sources/VaultCore/LibraryGrouping.swift VaultCore/Sources/VaultCore/LibrarySearch.swift VaultCore/Tests/VaultCoreTests/LibraryGroupingTests.swift VaultCore/Tests/VaultCoreTests/LibrarySearchTests.swift
git commit -m "Add month grouping and search matching for the library

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: SwiftData models, sources and document kinds (app)

**Files:**
- Create: `Vault/Models/VaultDocument.swift`, `Vault/Models/VaultCategory.swift`, `Vault/Models/DocumentSource.swift`, `Vault/Models/DocumentKind.swift`, `Vault/Models/VaultSchema.swift`
- Test: `VaultTests/ModelTests.swift`

**Interfaces:**
- Produces: `VaultDocument` and `VaultCategory` exactly as in the spec; `enum DocumentSource: String, Sendable, CaseIterable { case shared, inbox, picker, pasted, github, export }` with `var badge: String`; `DocumentKind.symbolName(for contentTypeIdentifier: String) -> String`; `VaultSchema.makeContainer(inMemory: Bool = false) throws -> ModelContainer`

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import SwiftData
import Testing
@testable import Vault

@Suite("Models")
struct ModelTests {

    @Test("A document can be saved and fetched from an in-memory store")
    func saveAndFetch() throws {
        let container = try VaultSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let document = VaultDocument(
            title: "M319 Lernziele", fileName: "m319.md", storedRelativePath: "x/m319.md",
            contentTypeIdentifier: "public.plain-text", sourceRaw: DocumentSource.pasted.rawValue,
            contentHash: "abc", createdAt: .now, byteSize: 3, textPreview: "M319")
        context.insert(document)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<VaultDocument>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "M319 Lernziele")
        #expect(fetched.first?.isFavorite == false)
        #expect(fetched.first?.categoryIsManual == false)
        #expect(fetched.first?.sourceRemoved == false)
    }

    @Test("Source badges match the spec: Shared, Pasted, GitHub, Export")
    func badges() {
        #expect(DocumentSource.shared.badge == "Shared")
        #expect(DocumentSource.inbox.badge == "Shared")
        #expect(DocumentSource.picker.badge == "Shared")
        #expect(DocumentSource.pasted.badge == "Pasted")
        #expect(DocumentSource.github.badge == "GitHub")
        #expect(DocumentSource.export.badge == "Export")
    }

    @Test("Each kind of file gets its SF Symbol")
    func symbols() {
        #expect(DocumentKind.symbolName(for: "com.adobe.pdf") == "doc.richtext")
        #expect(DocumentKind.symbolName(for: "public.png") == "photo")
        #expect(DocumentKind.symbolName(for: "public.html") == "globe")
        #expect(DocumentKind.symbolName(for: "public.swift-source") == "chevron.left.forwardslash.chevron.right")
        #expect(DocumentKind.symbolName(for: "public.plain-text") == "doc.text")
        #expect(DocumentKind.symbolName(for: "public.zip-archive") == "doc.zipper")
        #expect(DocumentKind.symbolName(for: "not.a.real.type") == "doc")
    }
}
```

- [ ] **Step 2: Implement.** (No local red run possible: app tests need the simulator.)

`Vault/Models/VaultDocument.swift`:

```swift
import Foundation
import SwiftData

/// One document in Vault. Only metadata lives here; the file itself is on disk
/// at `Application Support/Vault/Files/<storedRelativePath>`.
///
/// `@Model` turns this class into a SwiftData table. Every stored property is a column.
/// Model objects are not thread-safe: use them only inside the actor or view that fetched them.
@Model
final class VaultDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var fileName: String
    var storedRelativePath: String      // relative to Application Support/Vault/Files
    var contentTypeIdentifier: String   // UTType identifier
    var sourceRaw: String               // "shared", "inbox", "picker", "pasted", "github", "export"
    var sourceKey: String?              // GitHub path, or "export:<conversation-uuid>:<artifact-id>"
    var sourceRevision: String?         // GitHub blob SHA, or last artifact version
    var sourceRemoved: Bool             // true if it disappeared from GitHub; never auto-delete
    var contentHash: String             // SHA-256 hex
    var createdAt: Date                 // from the source if known, else import time
    var importedAt: Date
    var updatedAt: Date
    var byteSize: Int
    var textPreview: String             // first ~500 characters, for rows
    var searchText: String?             // first ~50,000 characters of extracted text
    var isFavorite: Bool
    var categoryIsManual: Bool
    var category: VaultCategory?

    init(id: UUID = UUID(), title: String, fileName: String, storedRelativePath: String,
         contentTypeIdentifier: String, sourceRaw: String, contentHash: String,
         createdAt: Date, byteSize: Int, textPreview: String) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.storedRelativePath = storedRelativePath
        self.contentTypeIdentifier = contentTypeIdentifier
        self.sourceRaw = sourceRaw
        self.sourceRemoved = false
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.importedAt = .now
        self.updatedAt = .now
        self.byteSize = byteSize
        self.textPreview = textPreview
        self.isFavorite = false
        self.categoryIsManual = false
    }
}
```

`Vault/Models/VaultCategory.swift`:

```swift
import Foundation
import SwiftData

/// A category. Created in Phase 1 so the database schema is stable from the start,
/// but seeded and used only from Phase 2 (classification spec).
@Model
final class VaultCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbolName: String
    var colorHex: String
    var order: Int
    var isFallback: Bool
    var matchesImageTypes: Bool
    var rulesData: Data                 // JSON-encoded VaultCore.CategoryRules
    @Relationship(deleteRule: .nullify, inverse: \VaultDocument.category)
    var documents: [VaultDocument] = []

    init(id: UUID = UUID(), name: String, symbolName: String, colorHex: String, order: Int,
         isFallback: Bool = false, matchesImageTypes: Bool = false, rulesData: Data) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.order = order
        self.isFallback = isFallback
        self.matchesImageTypes = matchesImageTypes
        self.rulesData = rulesData
    }
}
```

`Vault/Models/DocumentSource.swift`:

```swift
/// Where a document came from. Stored as its raw string in `VaultDocument.sourceRaw`.
/// A Swift enum with `String` raw values is like a Go string constant set, but the
/// compiler checks that a `switch` covers every case.
enum DocumentSource: String, Sendable, CaseIterable {
    case shared, inbox, picker, pasted, github, export

    /// The small badge on a library row. The spec has four badges; share sheet,
    /// Files inbox and file picker all count as "Shared".
    var badge: String {
        switch self {
        case .shared, .inbox, .picker: "Shared"
        case .pasted: "Pasted"
        case .github: "GitHub"
        case .export: "Export"
        }
    }
}
```

`Vault/Models/DocumentKind.swift`:

```swift
import UniformTypeIdentifiers

/// Picks the SF Symbol shown on a row. Order matters: HTML, source code and JSON
/// all conform to plain text too, so the specific checks come first.
enum DocumentKind {
    static func symbolName(for contentTypeIdentifier: String) -> String {
        guard let type = UTType(contentTypeIdentifier) else { return "doc" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .html) { return "globe" }
        if type.conforms(to: .sourceCode) || type.conforms(to: .json) {
            return "chevron.left.forwardslash.chevron.right"
        }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .presentation) { return "rectangle.on.rectangle" }
        if type.conforms(to: .spreadsheet) { return "tablecells" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }
}
```

`Vault/Models/VaultSchema.swift`:

```swift
import SwiftData

/// Builds the SwiftData container. `inMemory` is for tests: nothing touches the disk.
enum VaultSchema {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: VaultDocument.self, VaultCategory.self,
            configurations: configuration
        )
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Vault/Models VaultTests/ModelTests.swift
git commit -m "Add SwiftData models, document sources and kinds

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Push and verify on CI**

Run the CI commands from "How to run the tests". Expected: `✔ Suite "Models" passed`, 3 tests.

---

### Task 6: DocumentStore with file locations and text extraction (app)

**Files:**
- Create: `Vault/Services/FileLocations.swift`, `Vault/Services/TextExtractor.swift`, `Vault/Services/DocumentStore.swift`
- Create: `VaultTests/TestFiles.swift`
- Modify: `Vault/Info.plist` (add the Markdown type declaration)
- Test: `VaultTests/DocumentStoreTests.swift`

**Interfaces:**
- Consumes: `VaultDocument`, `DocumentSource`, `VaultSchema` (Task 5); `FileNaming`, `DocumentTitle`, `TextSnippets`, `ContentHash` (Tasks 1 to 3)
- Produces:
  - `struct FileLocations: Sendable { let filesDirectory: URL; let inboxDirectory: URL }` with `static func standard() throws -> FileLocations`, `static func temporary() throws -> FileLocations`, `func fileURL(forRelativePath: String) -> URL`
  - `enum ImportOutcome: Sendable, Equatable { case imported(UUID), alreadyInVault(UUID) }`
  - `struct DocumentSnapshot: Sendable, Equatable` (fields below)
  - `enum DocumentStoreError: Error, Equatable { case notFound(UUID) }`
  - `actor DocumentStore` with `init(modelContainer: ModelContainer, locations: FileLocations)`, `importFile(at: URL, source: DocumentSource) throws -> ImportOutcome`, `importPastedText(_: String) throws -> ImportOutcome`, `delete(_: UUID) throws`, `rename(_: UUID, to: String) throws`, `setFavorite(_: UUID, _: Bool) throws`, `snapshot(of: UUID) throws -> DocumentSnapshot?`, `allSnapshots() throws -> [DocumentSnapshot]`
  - `enum TestFiles { static func write(_ name: String, _ contents: String) throws -> URL; static func write(_ name: String, data: Data) throws -> URL }` (tests only)

- [ ] **Step 1: Write the test helper and the failing tests**

`VaultTests/TestFiles.swift`:

```swift
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
```

`VaultTests/DocumentStoreTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import UIKit
@testable import Vault

@Suite("DocumentStore")
struct DocumentStoreTests {
    let locations: FileLocations
    let store: DocumentStore

    // Swift Testing creates a fresh instance of this struct for every test,
    // so every test gets its own empty store and temp folder.
    init() throws {
        locations = try FileLocations.temporary()
        store = DocumentStore(modelContainer: try VaultSchema.makeContainer(inMemory: true), locations: locations)
    }

    func importedID(_ outcome: ImportOutcome) throws -> UUID {
        guard case .imported(let id) = outcome else {
            Issue.record("expected .imported, got \(outcome)")
            throw CancellationError()
        }
        return id
    }

    @Test("Importing a file copies it into the store and records it")
    func importsFile() async throws {
        let text = "# M319 Lernziele\n\nVariablen und Schleifen."
        let source = try TestFiles.write("m319-zusammenfassung.md", text)

        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)

        #expect(snapshot.title == "m319-zusammenfassung")
        #expect(snapshot.fileName == "m319-zusammenfassung.md")
        #expect(snapshot.storedRelativePath == "\(id.uuidString)/m319-zusammenfassung.md")
        #expect(snapshot.sourceRaw == "shared")
        #expect(snapshot.contentTypeIdentifier == "net.daringfireball.markdown")
        #expect(snapshot.textPreview == "# M319 Lernziele Variablen und Schleifen.")
        #expect(snapshot.searchText == text)
        #expect(snapshot.byteSize == Data(text.utf8).count)

        let stored = locations.fileURL(forRelativePath: snapshot.storedRelativePath)
        #expect(try String(contentsOf: stored, encoding: .utf8) == text)
        #expect(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)),
                "the original must stay where it was")
    }

    @Test("The same bytes under another name are not imported twice")
    func detectsDuplicate() async throws {
        let first = try TestFiles.write("a.md", "same content")
        let second = try TestFiles.write("b.md", "same content")

        let id = try importedID(try await store.importFile(at: first, source: .picker))
        let outcome = try await store.importFile(at: second, source: .picker)

        #expect(outcome == .alreadyInVault(id))
        #expect(try await store.allSnapshots().count == 1)
    }

    @Test("Pasted text becomes a Markdown document titled by its heading")
    func importsPastedText() async throws {
        let id = try importedID(try await store.importPastedText("## Subnetting\nCIDR notes"))
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)

        #expect(snapshot.title == "Subnetting")
        #expect(snapshot.fileName == "Subnetting.md")
        #expect(snapshot.sourceRaw == "pasted")
        #expect(snapshot.textPreview == "## Subnetting CIDR notes")
    }

    @Test("HTML previews show text, not tags")
    func htmlPreview() async throws {
        let source = try TestFiles.write("page.html", "<html><body><h1>Hallo</h1><p>Welt</p></body></html>")
        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        #expect(try #require(found).textPreview == "Hallo Welt")
    }

    @Test("Text is extracted from a PDF")
    func pdfText() async throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        let pdf = renderer.pdfData { context in
            context.beginPage()
            ("Subnetting Grundlagen" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
        }
        let source = try TestFiles.write("notes.pdf", data: pdf)

        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        #expect(try #require(found).searchText?.contains("Subnetting Grundlagen") == true)
    }

    @Test("Files without text get an empty preview and no search text")
    func binaryFile() async throws {
        let source = try TestFiles.write("slides.pptx", data: Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x01]))
        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)
        #expect(snapshot.textPreview == "")
        #expect(snapshot.searchText == nil)
    }

    @Test("Delete removes the record and the file")
    func deletes() async throws {
        let source = try TestFiles.write("temp.txt", "delete me")
        let id = try importedID(try await store.importFile(at: source, source: .shared))
        let folder = locations.filesDirectory.appending(path: id.uuidString, directoryHint: .isDirectory)
        #expect(FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))

        try await store.delete(id)

        #expect(try await store.snapshot(of: id) == nil)
        #expect(!FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
    }

    @Test("Rename changes the title, favorite toggles, unknown ids throw")
    func renameAndFavorite() async throws {
        let source = try TestFiles.write("draft.md", "text")
        let id = try importedID(try await store.importFile(at: source, source: .shared))

        try await store.rename(id, to: "  M117 Subnetting  ")
        try await store.setFavorite(id, true)
        let found = try await store.snapshot(of: id)
        let snapshot = try #require(found)
        #expect(snapshot.title == "M117 Subnetting")
        #expect(snapshot.isFavorite)

        let unknown = UUID()
        await #expect(throws: DocumentStoreError.notFound(unknown)) {
            try await store.rename(unknown, to: "x")
        }
    }
}
```

- [ ] **Step 2: Implement `FileLocations`**

```swift
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
```

- [ ] **Step 3: Implement `TextExtractor`**

```swift
import Foundation
import PDFKit
import UniformTypeIdentifiers
import VaultCore

/// Pulls searchable text out of a file's bytes. Phase 1 handles text-like files,
/// HTML and PDFs. Word, PowerPoint and Excel get no text; QuickLook still shows them.
enum TextExtractor {
    static func text(from data: Data, type: UTType) -> String? {
        if type.conforms(to: .pdf) {
            return PDFDocument(data: data)?.string
        }
        guard type.conforms(to: .text), let text = TextSnippets.decodeText(data) else {
            return nil
        }
        return type.conforms(to: .html) ? TextSnippets.plainText(fromHTML: text) : text
    }
}
```

- [ ] **Step 4: Implement `DocumentStore`**

```swift
import Foundation
import SwiftData
import UniformTypeIdentifiers
import VaultCore

/// What happened to one import.
enum ImportOutcome: Sendable, Equatable {
    case imported(UUID)
    /// The same bytes are already stored; carries the existing document's id.
    case alreadyInVault(UUID)
}

/// A plain copy of a document's fields. `@Model` objects must not cross actors,
/// so this `Sendable` struct is what leaves the store.
struct DocumentSnapshot: Sendable, Equatable {
    let id: UUID
    let title: String
    let fileName: String
    let storedRelativePath: String
    let contentTypeIdentifier: String
    let sourceRaw: String
    let contentHash: String
    let byteSize: Int
    let textPreview: String
    let searchText: String?
    let isFavorite: Bool
}

extension DocumentSnapshot {
    init(_ document: VaultDocument) {
        self.init(id: document.id, title: document.title, fileName: document.fileName,
                  storedRelativePath: document.storedRelativePath,
                  contentTypeIdentifier: document.contentTypeIdentifier,
                  sourceRaw: document.sourceRaw, contentHash: document.contentHash,
                  byteSize: document.byteSize, textPreview: document.textPreview,
                  searchText: document.searchText, isFavorite: document.isFavorite)
    }
}

enum DocumentStoreError: Error, Equatable {
    case notFound(UUID)
}

/// The only place that writes documents: files on disk and SwiftData records.
///
/// An `actor` is a type whose methods run one at a time, off the main thread.
/// Think of a goroutine that owns its state and serves requests over a channel;
/// callers `await` each method. `ModelActor` gives it its own SwiftData context.
/// Written out by hand instead of with the `@ModelActor` macro, because the
/// macro's generated init cannot take the extra `locations` parameter.
actor DocumentStore: ModelActor {
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer
    nonisolated let locations: FileLocations

    init(modelContainer: ModelContainer, locations: FileLocations) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.locations = locations
    }

    // MARK: - Import

    /// Copies the file at `url` into the store. The caller handles security-scoped access.
    func importFile(at url: URL, source: DocumentSource) throws -> ImportOutcome {
        let data = try Data(contentsOf: url)
        return try importData(data, rawFileName: url.lastPathComponent, title: nil, source: source)
    }

    /// Saves pasted text as a Markdown document (source S4).
    func importPastedText(_ text: String) throws -> ImportOutcome {
        let title = DocumentTitle.forPastedText(text)
        return try importData(Data(text.utf8), rawFileName: title + ".md", title: title, source: .pasted)
    }

    private func importData(_ data: Data, rawFileName: String, title: String?,
                            source: DocumentSource) throws -> ImportOutcome {
        let hash = ContentHash.sha256Hex(of: data)
        if let existing = try document(withHash: hash) {
            return .alreadyInVault(existing.id)
        }

        let id = UUID()
        let fileName = FileNaming.sanitize(rawFileName)
        let folder = locations.filesDirectory.appending(path: id.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appending(path: fileName, directoryHint: .notDirectory), options: .atomic)

        let ext = FileNaming.fileExtension(of: fileName)
        let type = ext.isEmpty ? UTType.data : (UTType(filenameExtension: ext) ?? .data)
        let text = TextExtractor.text(from: data, type: type)

        let document = VaultDocument(
            id: id,
            title: title ?? DocumentTitle.forFileName(fileName),
            fileName: fileName,
            storedRelativePath: "\(id.uuidString)/\(fileName)",
            contentTypeIdentifier: type.identifier,
            sourceRaw: source.rawValue,
            contentHash: hash,
            createdAt: .now,
            byteSize: data.count,
            textPreview: text.map { TextSnippets.preview(of: $0) } ?? ""
        )
        document.searchText = text.flatMap { TextSnippets.searchText(of: $0) }
        modelContext.insert(document)

        do {
            try modelContext.save()
        } catch {
            // Keep disk and database in step: no file without a record.
            modelContext.rollback()
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return .imported(id)
    }

    // MARK: - Changes

    /// Deletes the record first, then the file. A leftover file is harmless;
    /// a record pointing at a missing file is not.
    func delete(_ id: UUID) throws {
        guard let document = try document(withID: id) else { throw DocumentStoreError.notFound(id) }
        modelContext.delete(document)
        try modelContext.save()

        let folder = locations.filesDirectory.appending(path: id.uuidString, directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: folder)
        }
    }

    /// Changes the title shown in the library. The file on disk keeps its name.
    func rename(_ id: UUID, to newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document = try document(withID: id) else { throw DocumentStoreError.notFound(id) }
        guard !trimmed.isEmpty else { return }
        document.title = trimmed
        document.updatedAt = .now
        try modelContext.save()
    }

    func setFavorite(_ id: UUID, _ isFavorite: Bool) throws {
        guard let document = try document(withID: id) else { throw DocumentStoreError.notFound(id) }
        document.isFavorite = isFavorite
        document.updatedAt = .now
        try modelContext.save()
    }

    // MARK: - Reading

    func snapshot(of id: UUID) throws -> DocumentSnapshot? {
        try document(withID: id).map { DocumentSnapshot($0) }
    }

    func allSnapshots() throws -> [DocumentSnapshot] {
        try modelContext.fetch(FetchDescriptor<VaultDocument>()).map { DocumentSnapshot($0) }
    }

    private func document(withID id: UUID) throws -> VaultDocument? {
        var descriptor = FetchDescriptor<VaultDocument>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func document(withHash hash: String) throws -> VaultDocument? {
        var descriptor = FetchDescriptor<VaultDocument>(predicate: #Predicate { $0.contentHash == hash })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
```

- [ ] **Step 5: Declare the Markdown type.** In `Vault/Info.plist`, insert before the final `</dict>` (keys stay alphabetical by convention, but plist order does not matter):

```xml
	<key>UTImportedTypeDeclarations</key>
	<array>
		<dict>
			<key>UTTypeConformsTo</key>
			<array>
				<string>public.plain-text</string>
			</array>
			<key>UTTypeDescription</key>
			<string>Markdown document</string>
			<key>UTTypeIdentifier</key>
			<string>net.daringfireball.markdown</string>
			<key>UTTypeTagSpecification</key>
			<dict>
				<key>public.filename-extension</key>
				<array>
					<string>md</string>
					<string>markdown</string>
				</array>
				<key>public.mime-type</key>
				<array>
					<string>text/markdown</string>
				</array>
			</dict>
		</dict>
	</array>
```

An imported declaration is safe either way: if iOS 27 already declares Markdown, the system's declaration wins and ours is ignored.

- [ ] **Step 6: Check the plist locally, then push and verify on CI**

Run: `python3 -c "import plistlib; plistlib.load(open('Vault/Info.plist','rb')); print('plist ok')"`
Expected: `plist ok`.
Then CI. Expected: `✔ Suite "DocumentStore" passed`, 8 tests.

- [ ] **Step 7: Commit**

```bash
git add Vault/Services VaultTests/TestFiles.swift VaultTests/DocumentStoreTests.swift Vault/Info.plist
git commit -m "Add DocumentStore: copy, hash, de-duplicate, delete, rename

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: InboxScanner (app, source S2)

**Files:**
- Create: `Vault/Services/InboxScanner.swift`
- Test: `VaultTests/InboxScannerTests.swift`

**Interfaces:**
- Consumes: `DocumentStore.importFile(at:source:)`, `FileLocations`, `TestFiles` (Task 6)
- Produces: `struct InboxScanner: Sendable { let inboxDirectory: URL; let store: DocumentStore; func scan() async -> Summary }`, `struct InboxScanner.Summary: Sendable, Equatable { var imported: Int; var alreadyInVault: Int; var failed: Int }`

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Implement**

```swift
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
```

- [ ] **Step 3: Push and verify on CI.** Expected: `✔ Suite "InboxScanner" passed`, 4 tests.

- [ ] **Step 4: Commit**

```bash
git add Vault/Services/InboxScanner.swift VaultTests/InboxScannerTests.swift
git commit -m "Add InboxScanner for files saved to Vault in the Files app

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: ImportController (app)

**Files:**
- Create: `Vault/Features/Import/ImportController.swift`
- Test: `VaultTests/ImportControllerTests.swift`

**Interfaces:**
- Consumes: `DocumentStore`, `FileLocations`, `InboxScanner`, `DocumentSource`, `VaultDocument`
- Produces: `@MainActor @Observable final class ImportController` with `init(store: DocumentStore, locations: FileLocations)`, properties `duplicateOf: UUID?`, `errorMessage: String?`, `previewURL: URL?`, `isPasteSheetPresented: Bool`, and methods `importFiles(_: [URL], source: DocumentSource) async`, `importPastedText(_: String) async`, `delete(_: UUID) async`, `rename(_: UUID, to: String) async`, `setFavorite(_: UUID, _: Bool) async`, `openExisting(_: UUID) async`, `scanInbox() async`, `fileURL(for: VaultDocument) -> URL`

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Implement**

```swift
import Foundation
import Observation

/// The bridge between SwiftUI and the DocumentStore actor.
///
/// `@MainActor`: everything here runs on the main thread, because views read it.
/// `@Observable`: views that read a property redraw when it changes (a bit like a
/// reactive store in JavaScript). The slow work happens in `DocumentStore`,
/// reached with `await`, so the UI never freezes.
@MainActor
@Observable
final class ImportController {
    let store: DocumentStore
    let locations: FileLocations

    /// Set when an import found the same bytes already stored: the library shows "Already in Vault".
    var duplicateOf: UUID?
    /// A plain-language problem to show, if any.
    var errorMessage: String?
    /// The file QuickLook is showing. Nil means QuickLook is closed.
    var previewURL: URL?
    var isPasteSheetPresented = false

    private var isScanningInbox = false

    init(store: DocumentStore, locations: FileLocations) {
        self.store = store
        self.locations = locations
    }

    /// Files from the share sheet (S1) or the file picker (S3). Both hand over
    /// security-scoped URLs: access must be requested before reading and released after.
    func importFiles(_ urls: [URL], source: DocumentSource) async {
        for url in urls {
            let granted = url.startAccessingSecurityScopedResource()
            // `defer` runs when this loop iteration ends, like Go's defer at function end.
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            do {
                if case .alreadyInVault(let id) = try await store.importFile(at: url, source: source) {
                    duplicateOf = id
                }
            } catch {
                errorMessage = "Could not import \(url.lastPathComponent). \(error.localizedDescription)"
            }
        }
    }

    func importPastedText(_ text: String) async {
        do {
            if case .alreadyInVault(let id) = try await store.importPastedText(text) {
                duplicateOf = id
            }
            isPasteSheetPresented = false
        } catch {
            errorMessage = "Could not save the pasted text. \(error.localizedDescription)"
        }
    }

    func delete(_ id: UUID) async {
        do { try await store.delete(id) } catch {
            errorMessage = "Could not delete the document. \(error.localizedDescription)"
        }
    }

    func rename(_ id: UUID, to title: String) async {
        do { try await store.rename(id, to: title) } catch {
            errorMessage = "Could not rename the document. \(error.localizedDescription)"
        }
    }

    func setFavorite(_ id: UUID, _ isFavorite: Bool) async {
        do { try await store.setFavorite(id, isFavorite) } catch {
            errorMessage = "Could not change the favorite. \(error.localizedDescription)"
        }
    }

    /// Opens the document that a duplicate import pointed at.
    func openExisting(_ id: UUID) async {
        guard let snapshot = try? await store.snapshot(of: id) else { return }
        previewURL = locations.fileURL(forRelativePath: snapshot.storedRelativePath)
    }

    /// Source S2. Runs whenever the app becomes active; overlapping calls are ignored.
    func scanInbox() async {
        guard !isScanningInbox else { return }
        isScanningInbox = true
        defer { isScanningInbox = false }

        let summary = await InboxScanner(inboxDirectory: locations.inboxDirectory, store: store).scan()
        if summary.failed > 0 {
            errorMessage = "\(summary.failed) file(s) in the Vault inbox could not be imported. They are still in the inbox."
        }
    }

    func fileURL(for document: VaultDocument) -> URL {
        locations.fileURL(forRelativePath: document.storedRelativePath)
    }
}
```

- [ ] **Step 3: Push and verify on CI.** Expected: `✔ Suite "ImportController" passed`, 4 tests.

- [ ] **Step 4: Commit**

```bash
git add Vault/Features/Import/ImportController.swift VaultTests/ImportControllerTests.swift
git commit -m "Add ImportController between the views and the DocumentStore

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Library screen and paste sheet (app)

**Files:**
- Create: `Vault/Features/Library/LibraryView.swift`, `Vault/Features/Library/DocumentRow.swift`, `Vault/Features/Import/PasteSheet.swift`

**Interfaces:**
- Consumes: `ImportController` from the SwiftUI environment (Task 8), `VaultDocument`, `DocumentSource`, `DocumentKind` (Task 5), `LibraryGrouping`, `LibrarySearch`, `MonthGroup` (Task 4)
- Produces: `struct LibraryView: View` (no parameters; needs `.environment(ImportController)` and `.modelContainer(...)` from the app, Task 10), `struct DocumentRow: View { let document: VaultDocument }`, `struct PasteSheet: View`

No unit tests for the views themselves: their logic (grouping, search, store calls) is tested in Tasks 4 to 8. The device check in Task 11 covers the UI.

- [ ] **Step 1: Write `DocumentRow`**

```swift
import SwiftUI

/// One library row: type icon, title, date, source badge, favorite star.
/// (The category chip arrives in Phase 2.)
struct DocumentRow: View {
    let document: VaultDocument

    private var source: DocumentSource {
        DocumentSource(rawValue: document.sourceRaw) ?? .shared
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: DocumentKind.symbolName(for: document.contentTypeIdentifier))
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(document.createdAt, format: .dateTime.day().month().year())
                    Text(source.badge)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                    if document.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 2: Write `PasteSheet`**

```swift
import SwiftUI

/// Source S4. `PasteButton` reads the clipboard only when tapped, so iOS does not
/// show its "Allow Paste" prompt.
struct PasteSheet: View {
    @Environment(ImportController.self) private var controller

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Copy a Claude answer, then tap Paste. It is saved as a Markdown document.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                PasteButton(payloadType: String.self) { strings in
                    let text = strings.joined(separator: "\n\n")
                    // `Task { }` starts async work from a plain closure, like `go func() { }()`.
                    // `@MainActor in` pins it to the main thread, where the controller lives.
                    Task { @MainActor in
                        await controller.importPastedText(text)
                    }
                }
                .labelStyle(.titleAndIcon)
            }
            .padding()
            .navigationTitle("Paste as document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { controller.isPasteSheetPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 3: Write `LibraryView`**

```swift
import QuickLook
import SwiftData
import SwiftUI
import VaultCore

/// The main screen: every document, newest first, grouped by month, searchable.
struct LibraryView: View {
    @Environment(ImportController.self) private var controller

    // `@Query` fetches from SwiftData and keeps the array up to date as the store changes.
    @Query(sort: \VaultDocument.createdAt, order: .reverse) private var documents: [VaultDocument]

    // `@State` is view-local memory that survives redraws.
    @State private var searchText = ""
    @State private var isFileImporterPresented = false
    @State private var pendingDelete: VaultDocument?
    @State private var renaming: VaultDocument?
    @State private var renameText = ""

    private var filtered: [VaultDocument] {
        documents.filter {
            LibrarySearch.matches(searchText, fields: [$0.title, $0.textPreview, $0.searchText])
        }
    }

    var body: some View {
        // `@Bindable` lets us hand out two-way bindings ($) to the controller's properties.
        @Bindable var controller = controller

        NavigationStack {
            List {
                ForEach(LibraryGrouping.byMonth(filtered, calendar: .current, date: \.createdAt)) { group in
                    Section(monthTitle(year: group.year, month: group.month)) {
                        ForEach(group.items) { document in
                            row(for: document)
                        }
                    }
                }
            }
            .overlay { emptyState }
            .navigationTitle("Vault")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Import files", systemImage: "folder") { isFileImporterPresented = true }
                        Button("Paste as document", systemImage: "doc.on.clipboard") {
                            controller.isPasteSheetPresented = true
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.item],
                          allowsMultipleSelection: true) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let urls):
                        await controller.importFiles(urls, source: .picker)
                    case .failure(let error):
                        controller.errorMessage = "Could not open the file picker. \(error.localizedDescription)"
                    }
                }
            }
            .sheet(isPresented: $controller.isPasteSheetPresented) {
                PasteSheet()
            }
            .confirmationDialog(
                "Delete this document?",
                isPresented: isPresent($pendingDelete),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { document in
                let id = document.id
                Button("Delete", role: .destructive) {
                    Task { await controller.delete(id) }
                }
            } message: { document in
                Text("\"\(document.title)\" will be removed from Vault. This cannot be undone.")
            }
            .alert("Rename", isPresented: isPresent($renaming), presenting: renaming) { document in
                let id = document.id
                TextField("Title", text: $renameText)
                Button("Save") {
                    let title = renameText
                    Task { await controller.rename(id, to: title) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Already in Vault", isPresented: isPresent($controller.duplicateOf),
                   presenting: controller.duplicateOf) { id in
                Button("Open") { Task { await controller.openExisting(id) } }
                Button("OK", role: .cancel) {}
            } message: { _ in
                Text("This file is already in Vault.")
            }
            .alert("Something went wrong", isPresented: isPresent($controller.errorMessage),
                   presenting: controller.errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .quickLookPreview($controller.previewURL)
        }
    }

    // MARK: - Pieces

    private func row(for document: VaultDocument) -> some View {
        let id = document.id
        let fileURL = controller.fileURL(for: document)
        return Button {
            controller.previewURL = fileURL
        } label: {
            DocumentRow(document: document)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            let isFavorite = document.isFavorite
            Button(isFavorite ? "Unfavorite" : "Favorite",
                   systemImage: isFavorite ? "star.slash" : "star") {
                Task { await controller.setFavorite(id, !isFavorite) }
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                pendingDelete = document
            }
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                renameText = document.title
                renaming = document
            }
            ShareLink(item: fileURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                pendingDelete = document
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if documents.isEmpty {
            ContentUnavailableView(
                "No documents yet",
                systemImage: "tray",
                description: Text("Tap + to import a file or paste text. You can also save files to On My iPhone > Vault > Inbox in the Files app.")
            )
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private func monthTitle(year: Int, month: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? .now
        return date.formatted(.dateTime.month(.wide).year())
    }

    /// Turns "an optional is set" into the Bool binding that alerts and dialogs want.
    private func isPresent<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }
}
```

- [ ] **Step 4: Push and verify on CI.** This task only compiles (the placeholder still shows until Task 10). Expected: the **App tests** and **Unsigned device build** steps pass. Strict-concurrency errors in the view closures are the most likely failure: read them with `gh run view --log-failed` and fix them before moving on.

- [ ] **Step 5: Commit**

```bash
git add Vault/Features/Library/LibraryView.swift Vault/Features/Library/DocumentRow.swift Vault/Features/Import/PasteSheet.swift
git commit -m "Add the library screen, document rows and the paste sheet

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: App wiring, share sheet and Files app (app, sources S1 and S2)

**Files:**
- Modify: `Vault/App/VaultApp.swift` (full replacement below)
- Modify: `Vault/Info.plist` (add document types and Files app sharing)
- Delete: `Vault/Features/Library/LibraryPlaceholderView.swift`
- Test: `VaultTests/InfoPlistTests.swift`

**Interfaces:**
- Consumes: `LibraryView` (Task 9), `ImportController` (Task 8), `DocumentStore`, `FileLocations` (Task 6), `VaultSchema` (Task 5)

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Add to `Vault/Info.plist`,** before the final `</dict>`:

```xml
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Document</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.plain-text</string>
				<string>net.daringfireball.markdown</string>
				<string>public.html</string>
				<string>com.adobe.pdf</string>
				<string>public.image</string>
				<string>public.source-code</string>
				<string>public.json</string>
				<string>public.zip-archive</string>
				<string>org.openxmlformats.wordprocessingml.document</string>
				<string>com.microsoft.word.doc</string>
				<string>org.openxmlformats.presentationml.presentation</string>
				<string>com.microsoft.powerpoint.ppt</string>
				<string>org.openxmlformats.spreadsheetml.sheet</string>
				<string>com.microsoft.excel.xls</string>
			</array>
		</dict>
	</array>
	<key>LSSupportsOpeningDocumentsInPlace</key>
	<true/>
	<key>UIFileSharingEnabled</key>
	<true/>
```

Check: `python3 -c "import plistlib; plistlib.load(open('Vault/Info.plist','rb')); print('plist ok')"`, expected `plist ok`.

- [ ] **Step 3: Replace `Vault/App/VaultApp.swift`**

```swift
import SwiftData
import SwiftUI

// `@main` marks the program entry point, like func main() in Go.
// A SwiftUI App has no main loop you write yourself: you describe the scenes
// and the system runs them.
@main
struct VaultApp: App {
    private let container: ModelContainer
    @State private var controller: ImportController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let locations = try FileLocations.standard()
            let container = try VaultSchema.makeContainer()
            let store = DocumentStore(modelContainer: container, locations: locations)
            self.container = container
            _controller = State(initialValue: ImportController(store: store, locations: locations))
        } catch {
            // Without its storage Vault can do nothing useful. A friendlier screen
            // for this case is Phase 6 polish.
            fatalError("Vault could not open its storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(controller)
                // Source S1: "Open in Vault" from any app's share sheet lands here.
                .onOpenURL { url in
                    Task { await controller.importFiles([url], source: .shared) }
                }
        }
        .modelContainer(container)
        // Source S2: import the Files app inbox on launch and whenever Vault comes back.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await controller.scanInbox() }
            }
        }
    }
}
```

- [ ] **Step 4: Delete the placeholder**

```bash
git rm Vault/Features/Library/LibraryPlaceholderView.swift
```

- [ ] **Step 5: Push and verify on CI.** Expected: `✔ Suite "Info.plist" passed` (2 tests), all earlier suites still pass, the IPA artifact is produced. Count in the log: the VaultCore step must say `Test run with 26 tests` (FileNaming 7, DocumentTitle 5, TextSnippets 7, ContentHash 2, LibraryGrouping 2, LibrarySearch 3) and the App tests step `Test run with 22 tests` (Vault app 1, Models 3, DocumentStore 8, InboxScanner 4, ImportController 4, Info.plist 2).

- [ ] **Step 6: Commit**

```bash
git add Vault/App/VaultApp.swift Vault/Info.plist VaultTests/InfoPlistTests.swift
git commit -m "Wire up the library: share sheet, Files inbox, SwiftData container

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Device check with Onni (Phase 1 acceptance)

Nothing to code. This happens on the borrowed Mac, with the iPhone connected by cable. Steps for installing are in `docs/superpowers/specs/2026-09-21-build-ci-install-design.md`.

- [ ] **Step 1:** On the Mac: `git pull && xcodegen generate && open Vault.xcodeproj`, run on the iPhone.
- [ ] **Step 2 (S1):** In the Files app, long-press a PDF > Share. Is **Vault** in the list? Tap it. Repeat with a `.md` file. Record yes/no for each; this is the **[unverified]** item from the spec.
- [ ] **Step 3 (S2):** Files app > On My iPhone > Vault > Inbox. Save a `.png` and a `.docx` there (for example with "Save to Files" from Mail or the Claude app). Switch back to Vault. Both appear and the inbox is empty again.
- [ ] **Step 4:** Open each of the four documents. QuickLook shows all of them.
- [ ] **Step 5:** Import the same PDF again. "Already in Vault" appears, "Open" opens the existing one, the list still has one copy.
- [ ] **Step 6:** Paste a copied Claude answer through + > Paste as document. The title is the answer's first heading.
- [ ] **Step 7:** Search for a word that only appears inside the PDF. The PDF is found.
- [ ] **Step 8:** Record the results in CLAUDE.md section 16, and update the spec's Status line. Phase 1 is done only when steps 2 to 7 pass (S1 may fail if S2 works: the spec allows S2 as the fallback, but write down which).

## Risks to watch

1. **Nothing here has been compiled.** Every task's CI run is the first time the code meets a compiler. The most likely failures are Swift 6 strict-concurrency errors in view closures (Task 9) and the hand-written `ModelActor` conformance (Task 6). Read the error, fix the smallest thing, push again.
2. **The `Inbox` folder name** [unverified]. Older iOS versions used `Documents/Inbox` themselves for files opened from other apps, and apps could not always write into it. With `LSSupportsOpeningDocumentsInPlace = YES` iOS should not touch it, but if the device check shows files cannot be saved there, rename the folder in `FileLocations.standard()` (for example to `Add to Vault`) and update the empty-state text in `LibraryView`.
3. **List not refreshing after an import.** `@Query` should pick up saves made by the `DocumentStore` actor's own context. If the device shows new documents only after relaunch, that is the cause: record it and fix it before calling Phase 1 done.
