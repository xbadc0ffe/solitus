import Foundation
import SwiftData
@testable import Solitus

// Shared helpers for the test suites.
//
// Most tests are pinned to the date in the mockups: Friday 2026-11-20.
// November 2026 starts on a Sunday, so with the default week start the
// weeks are Nov 1-7, 8-14, 15-21, 22-28.

/// A day from its components.
func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
    DayKey(year: year, month: month, day: day)
}

/// A day in November 2026.
func nov(_ day: Int) -> DayKey {
    DayKey(year: 2026, month: 11, day: day)
}

/// The "today" most tests use.
let today = nov(20)

/// Compares doubles with a small tolerance. Nil is never close.
func isClose(_ value: Double?, _ expected: Double, tolerance: Double = 1e-9) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tolerance
}

/// Counts of 1 on each of the given November 2026 days.
func ones(_ days: Int...) -> DayCounts {
    var counts: DayCounts = [:]
    for d in days {
        counts[nov(d)] = 1
    }
    return counts
}

/// An in-memory store with a fresh context, kept alive by the fixture.
struct StoreFixture {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.makeInMemoryContainer()
    }

    /// Inserts and returns a task created at noon UTC on the given day.
    func makeTask(
        name: String = "Task",
        kind: TaskKind = .do,
        period: TaskPeriod = .daily,
        goalMode: GoalMode = .exactly,
        target: Int = 1,
        created: DayKey = nov(1)
    ) throws -> TaskItem {
        let clock = FixedClock(year: created.year, month: created.month, day: created.day)
        let task = TaskItem(
            name: name,
            kind: kind,
            period: period,
            goalMode: goalMode,
            target: target,
            createdAt: clock.now
        )
        context.insert(task)
        try context.save()
        return task
    }
}
