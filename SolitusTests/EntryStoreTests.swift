import Foundation
import SwiftData
import Testing
@testable import Solitus

/// `EntryStore`: one entry per task and day (DESIGN.md 5.2), and the rules
/// for logging and undo.
@Suite(.serialized)
struct EntryStoreTests {
    /// Friday 2026-11-20 at 11:17 UTC.
    private let clock = FixedClock(year: 2026, month: 11, day: 20, hour: 11, minute: 17)

    private func entryCount(_ fixture: StoreFixture) throws -> Int {
        try fixture.context.fetchCount(FetchDescriptor<Entry>())
    }

    @Test func loggingCreatesOneRowAndThenIncrementsIt() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(goalMode: .atLeast, target: 3)
        let store = EntryStore(context: fixture.context, clock: clock)

        let first = try store.logOne(for: task)
        let second = try store.logOne(for: task)
        #expect(first == .logged(periodCount: 1))
        #expect(second == .logged(periodCount: 2))

        let rows = try entryCount(fixture)
        #expect(rows == 1)
        #expect(task.entries.count == 1)
        #expect(task.entries.first?.dayKey == "2026-11-20")
        #expect(task.entries.first?.count == 2)
        #expect(task.entries.first?.updatedAt == clock.now)
        #expect(store.count(for: task, on: today) == 2)
    }

    @Test func undoToZeroDeletesTheRow() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(goalMode: .atLeast, target: 3)
        let store = EntryStore(context: fixture.context, clock: clock)

        try store.logOne(for: task)
        try store.logOne(for: task)

        let firstUndo = try store.undoOne(for: task)
        let rowsAfterFirst = try entryCount(fixture)
        #expect(firstUndo)
        #expect(store.count(for: task, on: today) == 1)
        #expect(rowsAfterFirst == 1)

        let secondUndo = try store.undoOne(for: task)
        let rowsAfterSecond = try entryCount(fixture)
        #expect(secondUndo)
        #expect(store.count(for: task, on: today) == 0)
        #expect(task.entries.isEmpty)
        #expect(rowsAfterSecond == 0)
    }

    @Test func undoWithNothingLoggedDoesNothing() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask()
        let store = EntryStore(context: fixture.context, clock: clock)

        let undone = try store.undoOne(for: task)
        let rows = try entryCount(fixture)
        #expect(!undone)
        #expect(rows == 0)
    }

    @Test func undoOnlyTouchesToday() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(goalMode: .atLeast, target: 3)
        let store = EntryStore(context: fixture.context, clock: clock)

        try store.add(2, to: task, on: nov(19))
        let undone = try store.undoOne(for: task)
        #expect(!undone)
        #expect(store.count(for: task, on: nov(19)) == 2)
    }

    @Test func exactlyTaskStopsAtItsTarget() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(goalMode: .exactly, target: 2)
        let store = EntryStore(context: fixture.context, clock: clock)

        let first = try store.logOne(for: task)
        let second = try store.logOne(for: task)
        let third = try store.logOne(for: task)
        #expect(first == .logged(periodCount: 1))
        #expect(second == .logged(periodCount: 2))
        #expect(third == .atTarget)
        #expect(store.count(for: task, on: today) == 2)
    }

    @Test func atLeastAndNoLimitTasksKeepCounting() throws {
        let fixture = try StoreFixture()
        let store = EntryStore(context: fixture.context, clock: clock)

        let atLeast = try fixture.makeTask(name: "Water", goalMode: .atLeast, target: 1)
        try store.logOne(for: atLeast)
        let pastTarget = try store.logOne(for: atLeast)
        #expect(pastTarget == .logged(periodCount: 2))

        let noLimit = try fixture.makeTask(name: "Journal", goalMode: .noLimit)
        try store.logOne(for: noLimit)
        let again = try store.logOne(for: noLimit)
        #expect(again == .logged(periodCount: 2))
    }

    @Test func avoidTasksRecordEveryOccurrence() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(name: "Drinks", kind: .avoid, goalMode: .atMost, target: 0)
        let store = EntryStore(context: fixture.context, clock: clock)

        let first = try store.logOne(for: task)
        let second = try store.logOne(for: task)
        #expect(first == .logged(periodCount: 1))
        #expect(second == .logged(periodCount: 2))
    }

    @Test func weeklyTargetCountsTheWholeWeek() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(name: "Gym", period: .weekly, goalMode: .exactly, target: 2)
        let store = EntryStore(context: fixture.context, clock: clock)

        // One earlier this week (Monday), one last week (ignored).
        try store.add(1, to: task, on: nov(16))
        try store.add(1, to: task, on: nov(10))
        #expect(store.currentPeriodCount(for: task) == 1)

        let first = try store.logOne(for: task)
        let second = try store.logOne(for: task)
        #expect(first == .logged(periodCount: 2))
        #expect(second == .atTarget)
        #expect(task.entries.count == 3)
    }

    @Test func weekStartDecidesWhichDaysShareAPeriod() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(name: "Gym", period: .weekly, goalMode: .exactly, target: 5)
        // Sunday Nov 15 is in the current week only when weeks start on Sunday.
        let sundayStore = EntryStore(context: fixture.context, clock: clock, weekStart: 1)
        let mondayStore = EntryStore(context: fixture.context, clock: clock, weekStart: 2)
        try sundayStore.add(1, to: task, on: nov(15))

        #expect(sundayStore.currentPeriodCount(for: task) == 1)
        #expect(mondayStore.currentPeriodCount(for: task) == 0)
    }

    @Test func addingToDifferentDaysKeepsSeparateRows() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(goalMode: .noLimit)
        let store = EntryStore(context: fixture.context, clock: clock)

        try store.add(1, to: task, on: nov(18))
        try store.add(3, to: task, on: nov(19))
        try store.add(1, to: task, on: nov(18))

        #expect(task.entries.count == 2)
        #expect(task.dayCounts == [nov(18): 2, nov(19): 3])
    }

    @Test func removingMoreThanExistsDeletesTheRowAndNeverGoesNegative() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(goalMode: .noLimit)
        let store = EntryStore(context: fixture.context, clock: clock)

        try store.add(2, to: task, on: nov(18))
        try store.add(-5, to: task, on: nov(18))
        #expect(task.entries.isEmpty)

        // Subtracting from a day with nothing logged creates nothing.
        try store.add(-1, to: task, on: nov(17))
        let rows = try entryCount(fixture)
        #expect(rows == 0)
    }
}
