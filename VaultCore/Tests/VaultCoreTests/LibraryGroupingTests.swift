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
