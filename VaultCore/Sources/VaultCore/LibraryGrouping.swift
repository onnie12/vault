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
