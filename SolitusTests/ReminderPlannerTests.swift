import Foundation
import Testing
@testable import Solitus

/// Reminder planning (DESIGN.md section 10).
struct ReminderPlannerTests {
    private let planner = ReminderPlanner()
    /// 11:17, the time in the Track mockup.
    private let now = 11 * 60 + 17

    private func medication(count: Int = 1, enabled: Bool = true) -> ReminderInput {
        ReminderInput(
            name: "Medication",
            rules: TaskRules(goalMode: .exactly, target: 3, createdDay: nov(1)),
            slots: [
                SlotRule(index: 0, minutes: 8 * 60),
                SlotRule(index: 1, minutes: 14 * 60),
                SlotRule(index: 2, minutes: 21 * 60),
            ],
            remindersEnabled: enabled,
            counts: count > 0 ? [today: count] : [:]
        )
    }

    @Test func dailyTaskRemindsAtEachRemainingSlot() {
        // One of three done at 11:17. Today: 14:00 and 21:00. The next six
        // days: all three slots each.
        let plan = planner.plan(for: medication(), today: today, minutesNow: now)
        #expect(plan.count == 2 + 6 * 3)

        let todays = plan.filter { $0.day == today }
        #expect(todays.map { $0.minutes } == [14 * 60, 21 * 60])
        #expect(todays.map { $0.slotIndex } == [1, 2])

        let tomorrow = plan.filter { $0.day == nov(21) }
        #expect(tomorrow.map { $0.minutes } == [8 * 60, 14 * 60, 21 * 60])
        #expect(plan.map { $0.day }.max() == nov(26))
    }

    @Test func finishedRepetitionsAndPastTimesAreSkipped() {
        // Nothing done, but 8:00 has already passed.
        let untouched = planner.plan(for: medication(count: 0), today: today, minutesNow: now)
        #expect(untouched.filter { $0.day == today }.map { $0.slotIndex } == [1, 2])

        // All three done: nothing more today.
        let done = planner.plan(for: medication(count: 3), today: today, minutesNow: now)
        #expect(done.filter { $0.day == today }.isEmpty)
        #expect(done.count == 6 * 3)

        // Two done before 14:00: only the 21:00 slot remains today.
        let two = planner.plan(for: medication(count: 2), today: today, minutesNow: now)
        #expect(two.filter { $0.day == today }.map { $0.slotIndex } == [2])
    }

    @Test func nothingIsPlannedWhenRemindersAreOffOrNotAllowed() {
        #expect(planner.plan(for: medication(enabled: false), today: today, minutesNow: now).isEmpty)

        let avoid = ReminderInput(
            name: "Drinks",
            rules: TaskRules(kind: .avoid, goalMode: .atMost, target: 0, createdDay: nov(1)),
            slots: [SlotRule(index: 0, minutes: 600)]
        )
        #expect(planner.plan(for: avoid, today: today, minutesNow: now).isEmpty)

        let noLimit = ReminderInput(
            name: "Journal",
            rules: TaskRules(goalMode: .noLimit, createdDay: nov(1)),
            slots: [SlotRule(index: 0, minutes: 600)]
        )
        #expect(planner.plan(for: noLimit, today: today, minutesNow: now).isEmpty)

        // Targets above four have no slots.
        let water = ReminderInput(
            name: "Water",
            rules: TaskRules(goalMode: .atLeast, target: 8, createdDay: nov(1)),
            slots: [SlotRule(index: 0, minutes: 600)]
        )
        #expect(planner.plan(for: water, today: today, minutesNow: now).isEmpty)

        var archivedRules = TaskRules(goalMode: .exactly, target: 1, createdDay: nov(1))
        archivedRules.isArchived = true
        let archived = ReminderInput(name: "Old", rules: archivedRules, slots: [SlotRule(index: 0, minutes: 600)])
        #expect(planner.plan(for: archived, today: today, minutesNow: now).isEmpty)
    }

    @Test func weeklyTaskRemindsOnPreferredDaysAtNine() {
        // Twice a week, Monday and Thursday. On Friday Nov 20 this week's
        // days have passed; the next two weeks are planned.
        let gym = ReminderInput(
            name: "Gym",
            rules: TaskRules(period: .weekly, goalMode: .exactly, target: 2, createdDay: nov(1)),
            slots: [SlotRule(index: 0, weekday: 2), SlotRule(index: 1, weekday: 5)]
        )
        let plan = planner.plan(for: gym, today: today, minutesNow: now)
        #expect(plan.map { $0.day } == [nov(23), nov(26), nov(30), day(2026, 12, 3)])
        #expect(plan.allSatisfy { $0.minutes == 9 * 60 })
    }

    @Test func weeklyReminderRespectsWhatIsDoneThisWeek() {
        let slots = [SlotRule(index: 0, weekday: 2), SlotRule(index: 1, weekday: 5)]
        let rules = TaskRules(period: .weekly, goalMode: .exactly, target: 2, createdDay: nov(1))
        let monday = nov(16)

        // Monday 08:00, nothing done: today's 9:00 reminder is planned.
        let fresh = ReminderInput(name: "Gym", rules: rules, slots: slots)
        let early = planner.plan(for: fresh, today: monday, minutesNow: 8 * 60)
        #expect(early.first?.day == monday)
        #expect(early.first?.slotIndex == 0)

        // Monday 10:00: 9:00 has passed, so the first is Thursday.
        let late = planner.plan(for: fresh, today: monday, minutesNow: 10 * 60)
        #expect(late.first?.day == nov(19))

        // One already done this week (on Sunday): the first repetition is
        // finished, so Monday is skipped but Thursday stays.
        let oneDone = ReminderInput(name: "Gym", rules: rules, slots: slots, counts: [nov(15): 1])
        let partial = planner.plan(for: oneDone, today: monday, minutesNow: 8 * 60)
        #expect(partial.first?.day == nov(19))
        #expect(partial.first?.slotIndex == 1)
        // Next week starts fresh.
        #expect(partial.contains { $0.day == nov(23) && $0.slotIndex == 0 })
    }

    @Test func monthlyPreferredDayIsClampedToTheMonth() {
        let budget = ReminderInput(
            name: "Budget review",
            rules: TaskRules(period: .monthly, goalMode: .exactly, target: 1, createdDay: nov(1)),
            slots: [SlotRule(index: 0, dayOfMonth: 31)]
        )
        // Planned 35 days ahead: Nov 30 (clamped). Dec 31 is out of range.
        let plan = planner.plan(for: budget, today: today, minutesNow: now)
        #expect(plan.map { $0.day } == [nov(30)])
        #expect(plan.first?.minutes == 9 * 60)

        // Already done this month: nothing until next month.
        var done = budget
        done.counts = [nov(3): 1]
        #expect(planner.plan(for: done, today: today, minutesNow: now).isEmpty)
    }

    @Test func combinedPlanIsSortedAndCapped() {
        var inputs: [ReminderInput] = []
        for _ in 0..<30 {
            inputs.append(medication(count: 0))
        }
        let plan = planner.plan(inputs, today: today, minutesNow: now)
        #expect(plan.count == ReminderPlanner.maxPending)
        // Soonest first.
        #expect(plan.first?.day == today)
        #expect(plan.first?.minutes == 14 * 60)
        for index in 1..<plan.count {
            let earlier = plan[index - 1]
            let later = plan[index]
            #expect(earlier.day < later.day || (earlier.day == later.day && earlier.minutes <= later.minutes))
        }
    }

    @Test func identifiersAreStableAndUnique() {
        let input = medication()
        let first = planner.plan(for: input, today: today, minutesNow: now)
        let second = planner.plan(for: input, today: today, minutesNow: now)
        #expect(first.map { $0.identifier } == second.map { $0.identifier })
        #expect(Set(first.map { $0.identifier }).count == first.count)
    }
}
