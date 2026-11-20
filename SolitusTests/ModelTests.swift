import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Solitus

/// The SwiftData models, the settings record, the value snapshots handed to
/// the services, and a few pure helpers of the design system.
@Suite(.serialized)
struct ModelTests {
    private let clock = FixedClock(year: 2026, month: 11, day: 20, hour: 11, minute: 17)

    private func rows<T: PersistentModel>(_ type: T.Type, in fixture: StoreFixture) throws -> Int {
        try fixture.context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: TaskItem

    @Test func newTaskHasTheDocumentedDefaults() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(name: "Walk")

        #expect(task.name == "Walk")
        #expect(task.kind == .do)
        #expect(task.period == .daily)
        #expect(task.goalMode == .exactly)
        #expect(task.target == 1)
        #expect(task.pinWhenLogged)
        #expect(task.streakGap == 0)
        #expect(isClose(task.fullAt, 0.85))
        #expect(task.heatMax == nil)
        #expect(task.quickStat == .progress)
        #expect(!task.isArchived)
        #expect(!task.remindersEnabled)
        #expect(task.colorHex == nil)
        #expect(task.entries.isEmpty)
        #expect(task.slots.isEmpty)
    }

    @Test func enumsAreStoredAsRawStrings() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask()

        task.kind = .avoid
        task.period = .monthly
        task.goalMode = .atMost
        task.quickStat = .avg90
        #expect(task.kindRaw == "avoid")
        #expect(task.periodRaw == "monthly")
        #expect(task.goalModeRaw == "atMost")
        #expect(task.quickStatRaw == "avg90")

        // An unknown raw value falls back instead of crashing.
        task.kindRaw = "something else"
        task.quickStatRaw = ""
        #expect(task.kind == .do)
        #expect(task.quickStat == .progress)
    }

    @Test func rulesSnapshotCopiesTheTask() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(kind: .do, period: .weekly, goalMode: .atLeast, target: 4, created: nov(3))
        task.streakGap = 1
        task.fullAt = 0.7
        task.heatMax = 6

        let rules = task.rules(calendar: clock.calendar)
        #expect(rules.kind == .do)
        #expect(rules.period == .weekly)
        #expect(rules.goalMode == .atLeast)
        #expect(rules.target == 4)
        #expect(rules.createdDay == nov(3))
        #expect(rules.streakGap == 1)
        #expect(isClose(rules.fullAt, 0.7))
        #expect(rules.heatMax == 6)
        #expect(!rules.isArchived)
    }

    @Test func dayCountsSkipUnreadableKeys() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask()
        for (key, count) in [("2026-11-19", 2), ("garbage", 9), ("2026-11-20", 1)] {
            let entry = Entry(dayKey: key, count: count, updatedAt: clock.now)
            fixture.context.insert(entry)
            task.entries.append(entry)
        }
        #expect(task.dayCounts == [nov(19): 2, nov(20): 1])
    }

    @Test func slotRulesComeBackInIndexOrder() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(target: 3)
        for (index, minutes) in [(2, 1260), (0, 480), (1, 840)] {
            let slot = Slot(index: index, minutes: minutes)
            fixture.context.insert(slot)
            task.slots.append(slot)
        }
        #expect(task.slotRules.map { $0.index } == [0, 1, 2])
        #expect(task.slotRules.map { $0.minutes } == [480, 840, 1260])
    }

    @Test func deletingATaskDeletesItsEntriesAndSlots() throws {
        let fixture = try StoreFixture()
        let task = try fixture.makeTask(goalMode: .noLimit)
        let store = EntryStore(context: fixture.context, clock: clock)
        try store.add(1, to: task, on: nov(19))
        try store.add(1, to: task, on: nov(20))
        let slot = Slot(index: 0, minutes: 480)
        fixture.context.insert(slot)
        task.slots.append(slot)
        try fixture.context.save()
        let entriesBefore = try rows(Entry.self, in: fixture)
        let slotsBefore = try rows(Slot.self, in: fixture)
        #expect(entriesBefore == 2)
        #expect(slotsBefore == 1)

        fixture.context.delete(task)
        try fixture.context.save()

        let tasksAfter = try rows(TaskItem.self, in: fixture)
        let entriesAfter = try rows(Entry.self, in: fixture)
        let slotsAfter = try rows(Slot.self, in: fixture)
        #expect(tasksAfter == 0)
        #expect(entriesAfter == 0)
        #expect(slotsAfter == 0)
    }

    // MARK: AppSettings

    @Test func settingsRecordIsCreatedOnceWithDefaults() throws {
        let fixture = try StoreFixture()
        let first = AppSettings.ensureExists(in: fixture.context)
        let second = AppSettings.ensureExists(in: fixture.context)

        let settingsRows = try rows(AppSettings.self, in: fixture)
        #expect(settingsRows == 1)
        #expect(first === second)
        #expect(first.weekStart == 1)
        #expect(first.appearance == .dark)
        #expect(first.surfaceStyle == .flat)
        #expect(first.effectsEnabled)
        #expect(first.glassTintHex == "#DCE6F5")
        #expect(first.streakEmphasis)
        #expect(first.streakPriorityBoost)
        #expect(first.trendGroupSize == 5)
        #expect(!first.notificationsRequested)
    }

    // MARK: Value types

    @Test func slotAllowanceFollowsTheTarget() {
        func allowed(_ kind: TaskKind, _ goalMode: GoalMode, _ target: Int) -> Int {
            TaskRules(kind: kind, goalMode: goalMode, target: target, createdDay: nov(1)).allowedSlotCount
        }
        #expect(allowed(.do, .exactly, 1) == 1)
        #expect(allowed(.do, .atLeast, 4) == 4)
        #expect(allowed(.do, .atLeast, 5) == 0)
        #expect(allowed(.do, .noLimit, 2) == 0)
        #expect(allowed(.avoid, .atMost, 2) == 0)
    }

    @Test func goalOptionsDependOnTheKind() {
        #expect(GoalMode.options(for: .do) == [.exactly, .atLeast, .noLimit])
        #expect(GoalMode.options(for: .avoid) == [.atMost, .noLimit])
    }

    @Test func slotsMatchTheirDay() {
        // Friday Nov 20.
        #expect(SlotRule(index: 0, minutes: 480).matches(today, period: .daily))
        #expect(SlotRule(index: 0, weekday: 6).matches(today, period: .weekly))
        #expect(!SlotRule(index: 0, weekday: 2).matches(today, period: .weekly))
        #expect(SlotRule(index: 0, dayOfMonth: 20).matches(today, period: .monthly))
        // Day 31 is clamped to the last day of a shorter month.
        #expect(SlotRule(index: 0, dayOfMonth: 31).matches(nov(30), period: .monthly))
        #expect(SlotRule(index: 0, dayOfMonth: 31).matches(day(2026, 2, 28), period: .monthly))
        #expect(!SlotRule(index: 0, dayOfMonth: 31).matches(nov(29), period: .monthly))
        // A slot of the wrong kind never matches.
        #expect(!SlotRule(index: 0, minutes: 480).matches(today, period: .weekly))
    }

    // MARK: Design system helpers

    @Test func sweepFillShowsTheHeldPartOfTheNextStep() {
        #expect(isClose(SweepFill.shownFraction(fraction: 0.5, sections: 4, phase: 0), 0.5))
        // Half way through a hold on a four-section card adds an eighth.
        #expect(isClose(SweepFill.shownFraction(fraction: 0.5, sections: 4, phase: 0.5), 0.625))
        #expect(isClose(SweepFill.shownFraction(fraction: 0, sections: 1, phase: 1), 1))
        #expect(isClose(SweepFill.shownFraction(fraction: 0.9, sections: 1, phase: 1), 1))
        #expect(isClose(SweepFill.shownFraction(fraction: -1, sections: 0, phase: 0), 0))
    }

    @Test func hexStringsParseOnlyWhenWellFormed() {
        #expect(Color(slHexString: "#DCE6F5") != nil)
        #expect(Color(slHexString: "DCE6F5") != nil)
        #expect(Color(slHexString: "#DCE6F") == nil)
        #expect(Color(slHexString: "#GGGGGG") == nil)
        #expect(Color(slHexString: "") == nil)
    }

    @Test func surfaceRolesHaveTheDocumentedRadii() {
        let metrics = SLMetrics.standard
        #expect(metrics.cornerRadius(for: .card) == 20)
        #expect(metrics.cornerRadius(for: .panel) == 20)
        #expect(metrics.cornerRadius(for: .statCard) == 18)
        #expect(metrics.cornerRadius(for: .row) == 16)
        #expect(metrics.cornerRadius(for: .well) == 14)
        #expect(metrics.cornerRadius(for: .heatCell) == 7)
        #expect(metrics.cornerRadius(for: .sheet) == 28)
        #expect(metrics.cornerRadius(for: .bar) == 31)
    }

    @Test func heatRampHasSixSteps() {
        let palette = SLTheme.dark.palette
        #expect(palette.heatRamp.count == HeatCalculator.maxStep + 1)
        #expect(palette.heatNumber.count == palette.heatRamp.count)
        #expect(palette.heatColor(step: 99) == palette.heatRamp.last)
        #expect(palette.heatColor(step: -1) == palette.heatRamp.first)
    }

    // MARK: Sample data

    #if DEBUG
    @Test func sampleDataMatchesTheMockups() throws {
        let fixture = try StoreFixture()
        SampleData.install(context: fixture.context, clock: clock)

        let tasks = try fixture.context.fetch(FetchDescriptor<TaskItem>()).sorted { $0.sortOrder < $1.sortOrder }
        #expect(tasks.map { $0.name } == ["Drinks", "Medication", "Gym", "Walk", "Read", "Budget review", "Journal", "Tobacco", "Stretch", "Water"])

        let store = EntryStore(context: fixture.context, clock: clock)
        func todayCount(_ name: String) -> Int? {
            tasks.first { $0.name == name }.map { store.count(for: $0, on: today) }
        }
        #expect(todayCount("Drinks") == 2)
        #expect(todayCount("Medication") == 1)
        #expect(todayCount("Walk") == 0)
        #expect(todayCount("Journal") == 1)
        #expect(todayCount("Tobacco") == 0)
        #expect(todayCount("Stretch") == 1)
        #expect(todayCount("Water") == 8)

        let medication = try #require(tasks.first { $0.name == "Medication" })
        #expect(medication.target == 3)
        #expect(medication.slotRules.map { $0.minutes } == [480, 840, 1260])

        let gym = try #require(tasks.first { $0.name == "Gym" })
        #expect(gym.period == .weekly)
        #expect(gym.target == 4)

        // History starts 120 days back and never has two rows for one day.
        for task in tasks {
            #expect(task.rules(calendar: clock.calendar).createdDay == today.adding(-SampleData.historyDays))
            #expect(Set(task.entries.map { $0.dayKey }).count == task.entries.count)
        }
    }
    #endif
}
