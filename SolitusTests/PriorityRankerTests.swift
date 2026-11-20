import Foundation
import Testing
@testable import Solitus

/// Track order (DESIGN.md 6.9).
struct PriorityRankerTests {
    private let ranker = PriorityRanker()
    /// 11:17, the time in the Track mockup.
    private let now = 11 * 60 + 17

    private func doRules(_ period: TaskPeriod = .daily, _ goalMode: GoalMode = .exactly, _ target: Int = 1) -> TaskRules {
        TaskRules(kind: .do, period: period, goalMode: goalMode, target: target, createdDay: nov(1))
    }

    private func avoidRules(_ goalMode: GoalMode = .atMost, _ target: Int = 0) -> TaskRules {
        TaskRules(kind: .avoid, goalMode: goalMode, target: target, createdDay: nov(1))
    }

    private let medicationSlots = [
        SlotRule(index: 0, minutes: 8 * 60),
        SlotRule(index: 1, minutes: 14 * 60),
        SlotRule(index: 2, minutes: 21 * 60),
    ]

    // MARK: Groups

    @Test func loggedAvoidTasksArePinnedToTheTop() {
        #expect(ranker.group(for: RankInput(rules: avoidRules(), periodCount: 2)) == .loggedAvoid)
        #expect(ranker.group(for: RankInput(rules: avoidRules(), pinWhenLogged: false, periodCount: 2)) == .quietAvoid)
        #expect(ranker.group(for: RankInput(rules: avoidRules(), periodCount: 0)) == .quietAvoid)
        #expect(ranker.group(for: RankInput(rules: avoidRules(.noLimit), periodCount: 1)) == .loggedAvoid)
    }

    @Test func doTasksAreUnmetMetOrNoLimit() {
        #expect(ranker.group(for: RankInput(rules: doRules(.daily, .exactly, 3), periodCount: 1)) == .unmet)
        #expect(ranker.group(for: RankInput(rules: doRules(.daily, .exactly, 3), periodCount: 3)) == .met)
        #expect(ranker.group(for: RankInput(rules: doRules(.daily, .atLeast, 8), periodCount: 9)) == .met)
        #expect(ranker.group(for: RankInput(rules: doRules(.daily, .noLimit), periodCount: 4)) == .noLimit)
    }

    // MARK: Daily urgency

    @Test func dailyTaskWithNoSlotsHasUrgencyOne() {
        let input = RankInput(rules: doRules())
        #expect(isClose(ranker.urgency(for: input, today: today, minutesNow: now), 1))
    }

    @Test func nextUnmetSlotIsTheOneAfterTheCount() {
        // One of three done at 11:17: the next slot is 14:00, 163 minutes
        // away, so "later today": 1 - (163 - 120) / 1320.
        let input = RankInput(rules: doRules(.daily, .exactly, 3), slots: medicationSlots, periodCount: 1)
        let expected = 1 - 43.0 / 1320.0
        #expect(isClose(ranker.urgency(for: input, today: today, minutesNow: now), expected))
    }

    @Test func slotWithinTwoHoursHasUrgencyTwo() {
        let input = RankInput(rules: doRules(.daily, .exactly, 3), slots: medicationSlots, periodCount: 1)
        #expect(isClose(ranker.urgency(for: input, today: today, minutesNow: 12 * 60 + 30), 2))
        #expect(isClose(ranker.urgency(for: input, today: today, minutesNow: 12 * 60), 2))
    }

    @Test func overdueSlotStartsAtThreeAndRises() {
        let input = RankInput(rules: doRules(.daily, .exactly, 3), slots: medicationSlots, periodCount: 1)
        // Exactly at the slot time counts as due.
        #expect(isClose(ranker.urgency(for: input, today: today, minutesNow: 14 * 60), 3))
        // One hour overdue: 3 + 60 / 1440.
        #expect(isClose(ranker.urgency(for: input, today: today, minutesNow: 15 * 60), 3 + 60.0 / 1440.0))

        // Nothing done at 11:17: the 8:00 slot is 197 minutes overdue.
        let untouched = RankInput(rules: doRules(.daily, .exactly, 3), slots: medicationSlots, periodCount: 0)
        #expect(isClose(ranker.urgency(for: untouched, today: today, minutesNow: now), 3 + 197.0 / 1440.0))
    }

    @Test func laterSlotRisesAsItApproaches() {
        let input = RankInput(rules: doRules(.daily, .exactly, 3), slots: medicationSlots, periodCount: 2)
        let morning = ranker.urgency(for: input, today: today, minutesNow: 9 * 60)
        let afternoon = ranker.urgency(for: input, today: today, minutesNow: 16 * 60)
        #expect(morning > 0)
        #expect(afternoon > morning)
        #expect(afternoon < 1)
    }

    // MARK: Weekly and monthly urgency

    @Test func weeklyTaskBehindOrDueToday() {
        // Friday: two days left in the week (Fri, Sat).
        let behind = RankInput(rules: doRules(.weekly, .exactly, 4), periodCount: 1)
        #expect(isClose(ranker.urgency(for: behind, today: today, minutesNow: now), 4))

        let mustAct = RankInput(rules: doRules(.weekly, .exactly, 4), periodCount: 2)
        #expect(isClose(ranker.urgency(for: mustAct, today: today, minutesNow: now), 3))
    }

    @Test func weeklyTaskOnAPreferredDay() {
        let friday = [SlotRule(index: 0, weekday: 6)]
        let tuesday = [SlotRule(index: 0, weekday: 3)]
        let onDay = RankInput(rules: doRules(.weekly, .exactly, 4), slots: friday, periodCount: 3)
        let offDay = RankInput(rules: doRules(.weekly, .exactly, 4), slots: tuesday, periodCount: 3)
        #expect(isClose(ranker.urgency(for: onDay, today: today, minutesNow: now), 2.5))
        // Otherwise remaining / days left = 1 / 2.
        #expect(isClose(ranker.urgency(for: offDay, today: today, minutesNow: now), 0.5))
    }

    @Test func monthlyTaskUsesDaysLeftInTheMonth() {
        // Nov 20: eleven days left (20 to 30). One remaining: 1 / 11.
        let relaxed = RankInput(rules: doRules(.monthly, .exactly, 1), periodCount: 0)
        #expect(isClose(ranker.urgency(for: relaxed, today: today, minutesNow: now), 1.0 / 11.0))

        // On the last day it must be done today.
        #expect(isClose(ranker.urgency(for: relaxed, today: nov(30), minutesNow: now), 3))

        // A preferred day of 31 is clamped to Nov 30.
        let clamped = RankInput(rules: doRules(.monthly, .exactly, 2), slots: [SlotRule(index: 0, dayOfMonth: 31)], periodCount: 1)
        #expect(isClose(ranker.urgency(for: clamped, today: nov(29), minutesNow: now), 0.5))
        let twoLeft = RankInput(rules: doRules(.monthly, .exactly, 3), slots: [SlotRule(index: 0, dayOfMonth: 20)], periodCount: 1)
        #expect(isClose(ranker.urgency(for: twoLeft, today: today, minutesNow: now), 2.5))
    }

    // MARK: Streak boost

    @Test func streakAtRiskAddsHalfAPoint() {
        let short = RankInput(rules: doRules(), currentStreak: 2)
        let long = RankInput(rules: doRules(), currentStreak: 3)
        #expect(isClose(ranker.urgency(for: short, today: today, minutesNow: now), 1))
        #expect(isClose(ranker.urgency(for: long, today: today, minutesNow: now), 1.5))

        let noBoost = PriorityRanker(streakPriorityBoost: false)
        #expect(isClose(noBoost.urgency(for: long, today: today, minutesNow: now), 1))
    }

    // MARK: Whole order

    @Test func ordersTheFiveGroupsTopToBottom() {
        let drinks = RankInput(rules: avoidRules(), sortOrder: 0, periodCount: 2)
        let medication = RankInput(rules: doRules(.daily, .exactly, 3), slots: medicationSlots, sortOrder: 1, periodCount: 1)
        let gym = RankInput(rules: doRules(.weekly, .exactly, 4), sortOrder: 2, periodCount: 2)
        let walk = RankInput(rules: doRules(), sortOrder: 3)
        let read = RankInput(rules: doRules(), sortOrder: 4)
        let journalLogged = RankInput(rules: doRules(.daily, .noLimit), sortOrder: 5, periodCount: 1)
        let notes = RankInput(rules: doRules(.daily, .noLimit), sortOrder: 6, periodCount: 0)
        let tobacco = RankInput(rules: avoidRules(), sortOrder: 7, periodCount: 0)
        let stretch = RankInput(rules: doRules(), sortOrder: 8, periodCount: 1)

        // Shuffled input; the result must not depend on input order.
        let ranked = ranker.rank(
            [stretch, tobacco, notes, journalLogged, read, walk, gym, medication, drinks],
            today: today,
            minutesNow: now
        )

        #expect(ranked.map { $0.id } == [
            drinks.id,          // 1: logged Avoid, pinned
            gym.id,             // 2: weekly, must act today (3)
            walk.id,            // 2: no slots (1), sort order 3
            read.id,            // 2: no slots (1), sort order 4
            medication.id,      // 2: next slot later today (about 0.97)
            notes.id,           // 3: no limit, untouched
            journalLogged.id,   // 3: no limit, already logged
            tobacco.id,         // 4: clear Avoid
            stretch.id,         // 5: met
        ])
        #expect(ranked.map { $0.group } == [.loggedAvoid, .unmet, .unmet, .unmet, .unmet, .noLimit, .noLimit, .quietAvoid, .met])
    }

    @Test func tiesFallBackToSortOrder() {
        let second = RankInput(rules: doRules(), sortOrder: 2)
        let first = RankInput(rules: doRules(), sortOrder: 1)
        let ranked = ranker.rank([second, first], today: today, minutesNow: now)
        #expect(ranked.map { $0.id } == [first.id, second.id])
    }
}
