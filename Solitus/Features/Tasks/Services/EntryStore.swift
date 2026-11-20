import Foundation
import SwiftData

/// The result of a hold on a card.
nonisolated enum LogResult: Hashable, Sendable {
    /// One was added. `periodCount` is the new count of the current period.
    case logged(periodCount: Int)
    /// An "exactly N" task is already at its target; nothing changed.
    case atTarget
}

/// The only place entries are created, changed or deleted.
///
/// It keeps the rule from DESIGN.md 5.2: at most one entry per task and day.
/// Incrementing finds or creates the row; decrementing to zero deletes it.
struct EntryStore {
    let context: ModelContext
    let clock: any AppClock
    let periods: PeriodCalculator

    init(context: ModelContext, clock: any AppClock = SystemClock(), weekStart: Int = 1) {
        self.context = context
        self.clock = clock
        self.periods = PeriodCalculator(weekStart: weekStart)
    }

    // MARK: Reading

    /// The entry for a task on a day, if anything was logged.
    func entry(for task: TaskItem, on day: DayKey) -> Entry? {
        let key = day.string
        return task.entries.first { $0.dayKey == key }
    }

    /// What was logged for a task on one day.
    func count(for task: TaskItem, on day: DayKey) -> Int {
        entry(for: task, on: day)?.count ?? 0
    }

    /// The count of the task's current period (today, this week, this month).
    func currentPeriodCount(for task: TaskItem) -> Int {
        periods.count(containing: clock.today, period: task.period, counts: task.dayCounts)
    }

    // MARK: Writing

    /// Logs one for today.
    ///
    /// For an "exactly N" task already at its target, nothing is saved.
    // OPEN: 12.6 holding past an "exactly" target is ignored; the caller
    // plays a soft haptic when it receives `.atTarget`.
    @discardableResult
    func logOne(for task: TaskItem) throws -> LogResult {
        let today = clock.today
        let before = periods.count(containing: today, period: task.period, counts: task.dayCounts)
        if task.kind == .do && task.goalMode == .exactly && before >= max(task.target, 1) {
            return .atTarget
        }
        try add(1, to: task, on: today)
        return .logged(periodCount: before + 1)
    }

    /// Subtracts one from today's count ("Undo last"). Returns false if there
    /// was nothing to undo.
    // OPEN: 12.4 undo lives on Task details and only affects today; there is
    // no direct entry of larger numbers.
    @discardableResult
    func undoOne(for task: TaskItem) throws -> Bool {
        let today = clock.today
        guard count(for: task, on: today) > 0 else { return false }
        try add(-1, to: task, on: today)
        return true
    }

    /// Changes a day's count by `delta`. The row is created when needed and
    /// deleted when the count reaches zero.
    func add(_ delta: Int, to task: TaskItem, on day: DayKey) throws {
        guard delta != 0 else { return }
        if let existing = entry(for: task, on: day) {
            let updated = existing.count + delta
            if updated <= 0 {
                task.entries.removeAll { $0.id == existing.id }
                context.delete(existing)
            } else {
                existing.count = updated
                existing.updatedAt = clock.now
            }
        } else if delta > 0 {
            let created = Entry(dayKey: day.string, count: delta, updatedAt: clock.now)
            context.insert(created)
            task.entries.append(created)
        }
        try context.save()
    }
}
