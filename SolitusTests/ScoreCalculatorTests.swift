import Foundation
import Testing
@testable import Solitus

/// Goal status, score and daily value (DESIGN.md 6.2 to 6.4).
struct ScoreCalculatorTests {
    private let scores = ScoreCalculator()

    private func rules(
        _ kind: TaskKind = .do,
        _ period: TaskPeriod = .daily,
        _ goalMode: GoalMode = .exactly,
        _ target: Int = 1,
        created: DayKey = nov(1)
    ) -> TaskRules {
        TaskRules(kind: kind, period: period, goalMode: goalMode, target: target, createdDay: created)
    }

    // MARK: 6.2

    @Test func doTasksAreMetWhenTheCountReachesTheTarget() {
        let exactly = rules(.do, .daily, .exactly, 3)
        #expect(!scores.isMet(exactly, count: 2))
        #expect(scores.isMet(exactly, count: 3))

        let atLeast = rules(.do, .daily, .atLeast, 3)
        #expect(!scores.isMet(atLeast, count: 2))
        #expect(scores.isMet(atLeast, count: 3))
        #expect(scores.isMet(atLeast, count: 9))
    }

    @Test func avoidTasksAreMetWhileWithinTheLimit() {
        let none = rules(.avoid, .daily, .atMost, 0)
        #expect(scores.isMet(none, count: 0))
        #expect(!scores.isMet(none, count: 1))

        let two = rules(.avoid, .weekly, .atMost, 2)
        #expect(scores.isMet(two, count: 2))
        #expect(!scores.isMet(two, count: 3))
    }

    @Test func noLimitTasksAreNeverMet() {
        #expect(!scores.isMet(rules(.do, .daily, .noLimit), count: 5))
        #expect(!scores.isMet(rules(.avoid, .daily, .noLimit), count: 0))
    }

    // MARK: 6.3

    @Test func doScoreIsTheFractionDoneCappedAtOne() {
        let task = rules(.do, .daily, .atLeast, 4)
        #expect(isClose(scores.score(task, count: 0), 0))
        #expect(isClose(scores.score(task, count: 1), 0.25))
        #expect(isClose(scores.score(task, count: 4), 1))
        #expect(isClose(scores.score(task, count: 7), 1))
    }

    @Test func avoidScoreIsAllOrNothing() {
        let task = rules(.avoid, .daily, .atMost, 1)
        #expect(isClose(scores.score(task, count: 0), 1))
        #expect(isClose(scores.score(task, count: 1), 1))
        #expect(isClose(scores.score(task, count: 2), 0))
    }

    @Test func noLimitTasksHaveNoScore() {
        #expect(scores.score(rules(.do, .daily, .noLimit), count: 3) == nil)
        #expect(scores.score(rules(.avoid, .daily, .noLimit), count: 3) == nil)
    }

    // MARK: 6.4

    @Test func dailyTaskValueIsThatDaysScore() {
        let task = rules(.do, .daily, .exactly, 2, created: nov(10))
        let counts: DayCounts = [nov(12): 1, nov(13): 2]
        #expect(isClose(scores.dailyValue(task, counts: counts, day: nov(11), today: today), 0))
        #expect(isClose(scores.dailyValue(task, counts: counts, day: nov(12), today: today), 0.5))
        #expect(isClose(scores.dailyValue(task, counts: counts, day: nov(13), today: today), 1))
    }

    @Test func daysOutsideTheTasksLifeHaveNoValue() {
        let task = rules(.do, .daily, .exactly, 1, created: nov(10))
        #expect(scores.dailyValue(task, counts: [:], day: nov(9), today: today) == nil)
        #expect(scores.dailyValue(task, counts: [:], day: nov(10), today: today) != nil)
        #expect(scores.dailyValue(task, counts: [:], day: nov(20), today: today) != nil)
        #expect(scores.dailyValue(task, counts: [:], day: nov(21), today: today) == nil)
    }

    @Test func noLimitTasksHaveNoDailyValue() {
        let task = rules(.do, .daily, .noLimit)
        #expect(scores.dailyValue(task, counts: [today: 3], day: today, today: today) == nil)
    }

    @Test func finishedWeekGivesEveryDayTheWeeksScore() {
        // Week Nov 8-14, target 4, three done.
        let task = rules(.do, .weekly, .exactly, 4)
        let counts: DayCounts = [nov(9): 1, nov(11): 2]
        for d in 8...14 {
            #expect(isClose(scores.dailyValue(task, counts: counts, day: nov(d), today: today), 0.75))
        }
    }

    @Test func currentWeekUsesPaceSoFar() {
        let task = rules(.do, .weekly, .exactly, 4)
        // Friday is day 6 of 7: ceil(4 * 6 / 7) = 4 expected by now.
        let two: DayCounts = [nov(16): 1, nov(18): 1]
        #expect(isClose(scores.dailyValue(task, counts: two, day: today, today: today), 0.5))
        // Earlier days of the same unfinished week get the same pace value.
        #expect(isClose(scores.dailyValue(task, counts: two, day: nov(15), today: today), 0.5))

        // Sunday is day 1 of 7: ceil(4 / 7) = 1 expected.
        #expect(isClose(scores.dailyValue(task, counts: [:], day: nov(15), today: nov(15)), 0))
        #expect(isClose(scores.dailyValue(task, counts: [nov(15): 1], day: nov(15), today: nov(15)), 1))

        // Ahead of pace is capped at 1.
        #expect(isClose(scores.dailyValue(task, counts: [nov(15): 3], day: nov(15), today: nov(15)), 1))
    }

    @Test func currentMonthUsesPaceSoFar() {
        // Target 1: ceil(1 * 20 / 30) = 1 expected by Nov 20.
        let once = rules(.do, .monthly, .exactly, 1)
        #expect(isClose(scores.dailyValue(once, counts: [:], day: today, today: today), 0))
        #expect(isClose(scores.dailyValue(once, counts: [nov(3): 1], day: today, today: today), 1))

        // Target 6: ceil(6 * 20 / 30) = 4 expected; 3 done.
        let six = rules(.do, .monthly, .atLeast, 6)
        #expect(isClose(scores.dailyValue(six, counts: [nov(2): 3], day: today, today: today), 0.75))
    }

    @Test func currentPeriodAvoidIsOneWhileWithinTheLimit() {
        let task = rules(.avoid, .weekly, .atMost, 2)
        #expect(isClose(scores.dailyValue(task, counts: [nov(16): 2], day: today, today: today), 1))
        #expect(isClose(scores.dailyValue(task, counts: [nov(16): 3], day: today, today: today), 0))
    }

    @Test func weekStartChangesWhichWeekADayBelongsTo() {
        // With a Monday start, Sunday Nov 15 belongs to the finished week
        // Nov 9-15, not to the current one.
        let monday = ScoreCalculator(periods: PeriodCalculator(weekStart: 2))
        let task = rules(.do, .weekly, .exactly, 2)
        let counts: DayCounts = [nov(15): 2]
        #expect(isClose(monday.dailyValue(task, counts: counts, day: nov(15), today: today), 1))
        #expect(isClose(monday.dailyValue(task, counts: counts, day: nov(16), today: today), 0))
    }
}
