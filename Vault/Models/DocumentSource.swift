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
