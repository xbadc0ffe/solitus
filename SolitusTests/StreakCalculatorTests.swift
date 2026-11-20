import Foundation
import Testing
@testable import Solitus

/// Streaks (DESIGN.md 6.7).
struct StreakCalculatorTests {
    private let streaks = StreakCalculator()

    private func daily(created: DayKey = nov(10), gap: Int = 0, counts: DayCounts) -> TaskHistory {
        TaskHistory(rules: TaskRules(createdDay: created, streakGap: gap), counts: counts)
    }

    @Test func countsMetPeriodsBackFromNow() {
        // Done Nov 10-12, 14-15, 18-19. Today (Nov 20) is not done yet.
        let task = daily(counts: ones(10, 11, 12, 14, 15, 18, 19))
        let summary = streaks.summary(for: task, today: today)
        #expect(summary.current == 2)
        #expect(summary.best == 3)
        #expect(isClose(summary.average, 7.0 / 3.0))
    }

    @Test func currentPeriodCountsOnceMet() {
        let task = daily(counts: ones(18, 19, 20))
        #expect(streaks.summary(for: task, today: today).current == 3)
    }

    @Test func unfinishedCurrentPeriodDoesNotBreakTheStreak() {
        let task = daily(counts: ones(18, 19))
        #expect(streaks.summary(for: task, today: today).current == 2)
        // Once the day has ended unmet, the streak is over.
        #expect(streaks.summary(for: task, today: nov(21)).current == 0)
        #expect(streaks.summary(for: task, today: nov(21)).best == 2)
    }

    @Test func gapsUpToTheAllowanceAreForgivenAndAddNothing() {
        // One missed day (13) is forgiven; two in a row (16, 17) are not.
        let task = daily(gap: 1, counts: ones(10, 11, 12, 14, 15, 18, 19))
        let summary = streaks.summary(for: task, today: today)
        #expect(summary.best == 5)
        #expect(summary.current == 2)
        #expect(isClose(summary.average, 3.5))
    }

    @Test func trailingGapWithinTheAllowanceKeepsTheStreakAlive() {
        // Done Nov 10-18, missed 19. With a gap of 1 the streak survives.
        let counts = ones(10, 11, 12, 13, 14, 15, 16, 17, 18)
        #expect(streaks.summary(for: daily(gap: 1, counts: counts), today: today).current == 9)
        #expect(streaks.summary(for: daily(gap: 0, counts: counts), today: today).current == 0)
        #expect(streaks.summary(for: daily(gap: 0, counts: counts), today: today).best == 9)
    }

    @Test func noHistoryMeansNoStreaks() {
        let summary = streaks.summary(for: daily(counts: [:]), today: today)
        #expect(summary == StreakSummary.none)
    }

    @Test func taskCreatedInTheFutureHasNoStreak() {
        let task = daily(created: nov(25), counts: [:])
        #expect(streaks.summary(for: task, today: today) == StreakSummary.none)
    }

    @Test func weeklyStreaksCountWeeks() {
        // Created Sunday Nov 1, twice a week.
        // Nov 1-7: 2 (met). Nov 8-14: 1 (not met). Nov 15-21: 2 (met).
        let rules = TaskRules(period: .weekly, goalMode: .exactly, target: 2, createdDay: nov(1))
        let counts: DayCounts = [nov(2): 1, nov(5): 1, nov(10): 1, nov(16): 1, nov(18): 1]
        let summary = streaks.summary(for: TaskHistory(rules: rules, counts: counts), today: today)
        #expect(summary.current == 1)
        #expect(summary.best == 1)
        #expect(isClose(summary.average, 1))
    }

    @Test func monthlyStreaksCountMonths() {
        // Created in August; done in Aug, Sep and Oct, not yet in Nov.
        let rules = TaskRules(period: .monthly, createdDay: day(2026, 8, 15))
        let counts: DayCounts = [day(2026, 8, 20): 1, day(2026, 9, 3): 1, day(2026, 10, 30): 1]
        let summary = streaks.summary(for: TaskHistory(rules: rules, counts: counts), today: today)
        #expect(summary.current == 3)
        #expect(summary.best == 3)
    }

    @Test func avoidStreakGrowsOnClearDays() {
        // At most 0 per day. One slip on Nov 13.
        let rules = TaskRules(kind: .avoid, goalMode: .atMost, target: 0, createdDay: nov(10))
        let task = TaskHistory(rules: rules, counts: [nov(13): 2])
        let summary = streaks.summary(for: task, today: today)
        #expect(summary.current == 7)   // Nov 14 to Nov 20
        #expect(summary.best == 7)
        #expect(isClose(summary.average, 5))   // streaks of 3 and 7
    }

    @Test func avoidSlipTodayEndsTheStreakAtOnce() {
        let rules = TaskRules(kind: .avoid, goalMode: .atMost, target: 0, createdDay: nov(10))
        let task = TaskHistory(rules: rules, counts: [today: 1])
        let summary = streaks.summary(for: task, today: today)
        #expect(summary.current == 0)
        #expect(summary.best == 10)
    }

    @Test func noLimitDoTaskIsMetByAnyCount() {
        let rules = TaskRules(goalMode: .noLimit, createdDay: nov(10))
        let task = TaskHistory(rules: rules, counts: [nov(18): 4, nov(19): 1, nov(20): 2])
        #expect(streaks.summary(for: task, today: today).current == 3)
    }

    @Test func noLimitAvoidTaskHasNoStreak() {
        let rules = TaskRules(kind: .avoid, goalMode: .noLimit, createdDay: nov(10))
        let task = TaskHistory(rules: rules, counts: [:])
        #expect(streaks.summary(for: task, today: today) == StreakSummary.none)
    }
}
