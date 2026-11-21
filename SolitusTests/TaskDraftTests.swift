import Foundation
import SwiftData
import Testing
@testable import Solitus

@Suite struct TaskDraftTests {
    @Test func aNewDraftIsExactlyOnceADay() {
        let draft = TaskDraft()
        #expect(draft.kind == .do)
        #expect(draft.period == .daily)
        #expect(draft.goalMode == .exactly)
        #expect(draft.target == 1)
        #expect(draft.allowedSlotCount == 1)
        #expect(draft.slots.count == 1)
        #expect(!draft.canSave)
    }

    @Test func aNameOfSpacesCannotBeSaved() {
        var draft = TaskDraft()
        draft.name = "   "
        #expect(!draft.canSave)
        draft.name = "  Walk "
        #expect(draft.canSave)
        #expect(draft.trimmedName == "Walk")
    }

    @Test func switchingTypeResetsTheGoal() {
        var draft = TaskDraft()
        draft.setTarget(3)
        draft.setKind(.avoid)
        #expect(draft.goalMode == .atMost)
        #expect(draft.target == 0)
        #expect(draft.allowedSlotCount == 0)
        #expect(draft.slots.isEmpty)

        draft.setKind(.do)
        #expect(draft.goalMode == .exactly)
        #expect(draft.target == 1)
    }

    @Test func aGoalModeOfTheOtherKindIsRefused() {
        var draft = TaskDraft()
        draft.setGoalMode(.atMost)
        #expect(draft.goalMode == .exactly)
        draft.setGoalMode(.atLeast)
        #expect(draft.goalMode == .atLeast)
    }

    @Test func targetStaysInRange() {
        var draft = TaskDraft()
        draft.setTarget(0)
        #expect(draft.target == 1)
        draft.setTarget(500)
        #expect(draft.target == TaskDraft.maxTarget)
        draft.setKind(.avoid)
        draft.setTarget(-2)
        #expect(draft.target == 0)
    }

    @Test func slotsFollowTheTargetUpToFour() {
        var draft = TaskDraft()
        draft.setTarget(3)
        #expect(draft.slots.count == 3)
        draft.setSlot(SlotRule(index: 9, minutes: 480), at: 2)
        #expect(draft.slotRules == [SlotRule(index: 2, minutes: 480)])

        draft.setTarget(2)
        #expect(draft.slots.count == 2)
        #expect(draft.slotRules.isEmpty)

        draft.setTarget(5)
        #expect(draft.allowedSlotCount == 0)
        #expect(draft.slots.isEmpty)
    }

    @Test func noLimitHidesTheTargetAndSlotsAndTurnsRemindersOff() {
        var draft = TaskDraft()
        draft.remindersEnabled = true
        draft.setGoalMode(.noLimit)
        #expect(!draft.showsTarget)
        #expect(draft.allowedSlotCount == 0)
        #expect(!draft.remindersEnabled)
    }

    @Test func changingThePeriodClearsTheSlots() {
        var draft = TaskDraft()
        draft.setTarget(2)
        draft.setSlot(SlotRule(index: 0, minutes: 480), at: 0)
        draft.setPeriod(.weekly)
        #expect(draft.slots == [nil, nil])
    }

    @Test func loadsAStoredTask() {
        let rules = TaskRules(
            kind: .do, period: .weekly, goalMode: .atLeast, target: 3,
            createdDay: day(2026, 1, 1), streakGap: 1, fullAt: 0.7
        )
        let draft = TaskDraft(
            name: "Gym", symbol: "dumbbell", rules: rules,
            slots: [SlotRule(index: 1, weekday: 4)],
            remindersEnabled: true, pinWhenLogged: true
        )
        #expect(draft.name == "Gym")
        #expect(draft.goalMode == .atLeast)
        #expect(draft.target == 3)
        #expect(draft.slots == [nil, SlotRule(index: 1, weekday: 4), nil])
        #expect(draft.streakGap == 1)
        #expect(draft.fullAtPercent == 70)
        #expect(draft.remindersEnabled)
    }

    @Test func defaultSlotsMatchThePeriod() {
        #expect(TaskDraft.defaultSlot(index: 0, period: .daily) == SlotRule(index: 0, minutes: 480))
        #expect(TaskDraft.defaultSlot(index: 1, period: .weekly) == SlotRule(index: 1, weekday: 4))
        #expect(TaskDraft.defaultSlot(index: 3, period: .monthly) == SlotRule(index: 3, dayOfMonth: 22))
    }

    @Test func labels() {
        var draft = TaskDraft()
        #expect(draft.targetLabel == "Times per day")
        draft.setPeriod(.weekly)
        draft.setKind(.avoid)
        #expect(draft.targetLabel == "Allowed per week")
        #expect(TaskDraft.gapLabel(0, period: .daily) == "None")
        #expect(TaskDraft.gapLabel(1, period: .daily) == "1 day")
        #expect(TaskDraft.gapLabel(2, period: .monthly) == "2 months")
    }
}

/// Saving a draft into the store.
@Suite(.serialized)
struct TaskDraftStoreTests {
    private let clock = FixedClock(year: 2026, month: 11, day: 20)

    @Test func insertingPlacesTheTaskLastAndStoresItsSlots() throws {
        let fixture = try StoreFixture()
        let existing = try fixture.makeTask(name: "First")
        existing.sortOrder = 4

        var draft = TaskDraft()
        draft.name = " Medication "
        draft.symbol = "pills"
        draft.setTarget(2)
        draft.setSlot(SlotRule(index: 0, minutes: 480), at: 0)
        draft.setSlot(SlotRule(index: 1, minutes: 1260), at: 1)
        let task = draft.insert(into: fixture.context, now: clock.now)
        try fixture.context.save()

        #expect(task.name == "Medication")
        #expect(task.sortOrder == 5)
        #expect(task.target == 2)
        #expect(task.createdAt == clock.now)
        #expect(task.slotRules == [SlotRule(index: 0, minutes: 480), SlotRule(index: 1, minutes: 1260)])
        let slotRows = try fixture.context.fetchCount(FetchDescriptor<Slot>())
        #expect(slotRows == 2)
    }

    @Test func applyingReplacesTheOldSlots() throws {
        let fixture = try StoreFixture()
        var draft = TaskDraft()
        draft.name = "Gym"
        draft.setTarget(3)
        draft.setSlot(SlotRule(index: 0, minutes: 480), at: 0)
        draft.setSlot(SlotRule(index: 2, minutes: 1200), at: 2)
        let task = draft.insert(into: fixture.context, now: clock.now)
        try fixture.context.save()

        var edited = TaskDraft(task: task, calendar: clock.calendar)
        #expect(edited.slotRules.count == 2)
        edited.setKind(.avoid)
        edited.streakGap = 2
        edited.apply(to: task, context: fixture.context)
        try fixture.context.save()

        #expect(task.kind == .avoid)
        #expect(task.goalMode == .atMost)
        #expect(task.target == 0)
        #expect(task.streakGap == 2)
        #expect(task.slots.isEmpty)
        let slotRows = try fixture.context.fetchCount(FetchDescriptor<Slot>())
        #expect(slotRows == 0)
    }
}
