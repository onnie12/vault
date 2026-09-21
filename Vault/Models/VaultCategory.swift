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
