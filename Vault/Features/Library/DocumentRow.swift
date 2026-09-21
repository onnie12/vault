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
