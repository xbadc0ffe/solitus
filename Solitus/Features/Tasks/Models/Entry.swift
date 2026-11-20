import Foundation
import SwiftData

/// What was logged for one task on one calendar day (DESIGN.md 5.2).
///
/// There is at most one entry per task and `dayKey`. `EntryStore` enforces
/// that; nothing else should create or delete entries.
@Model
final class Entry {
    var id: UUID = UUID()
    var task: TaskItem?
    /// `yyyy-MM-dd` in the device's local calendar at the time of logging.
    /// A string, not a `Date`, so time zone changes never move an entry.
    var dayKey: String = ""
    /// Running total for that day.
    var count: Int = 0
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(dayKey: String, count: Int, updatedAt: Date) {
        self.id = UUID()
        self.dayKey = dayKey
        self.count = count
        self.updatedAt = updatedAt
    }
}
