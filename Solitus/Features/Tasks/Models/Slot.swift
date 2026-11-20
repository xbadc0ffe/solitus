import Foundation
import SwiftData

/// A preferred time or day for one of a task's repetitions (DESIGN.md 5.3).
/// A suggestion used for ordering and reminders, never a requirement.
///
/// Exactly one of `minutes`, `weekday` and `dayOfMonth` is set, matching the
/// task's period.
@Model
final class Slot {
    var id: UUID = UUID()
    var task: TaskItem?
    /// 0-based position.
    var index: Int = 0
    /// Daily tasks: minutes after midnight.
    var minutes: Int?
    /// Weekly tasks: 1 (Sunday) to 7.
    var weekday: Int?
    /// Monthly tasks: 1 to 31, clamped to the month's length when used.
    var dayOfMonth: Int?

    init(index: Int, minutes: Int? = nil, weekday: Int? = nil, dayOfMonth: Int? = nil) {
        self.id = UUID()
        self.index = index
        self.minutes = minutes
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
    }
}
