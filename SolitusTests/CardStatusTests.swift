import Foundation
import Testing
@testable import Solitus

@Suite struct CardStatusTests {
    private func snapshot(count: Int, met: Bool = false, avg30: Double? = nil, streak: Int = 0) -> TaskSnapshot {
        TaskSnapshot(
            periodCount: count,
            todayCount: count,
            isMet: met,
            average30: avg30,
            average90: nil,
            streak: StreakSummary(current: streak, best: streak, average: Double(streak))
        )
    }

    private func rules(_ kind: TaskKind = .do, _ mode: GoalMode = .exactly, _ target: Int = 1, _ period: TaskPeriod = .daily) -> TaskRules {
        TaskRules(kind: kind, period: period, goalMode: mode, target: target, createdDay: day(2026, 1, 1))
    }

    @Test func doTaskShowsCountOverTargetThenDone() {
        let r = rules(.do, .exactly, 3)
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 1)) == CardStatus(value: "1/3", caption: "today"))
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 3, met: true)) == CardStatus(value: "Done", caption: "today"))
    }

    @Test func atLeastKeepsCountingPastTheTarget() {
        let r = rules(.do, .atLeast, 8)
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 9, met: true)) == CardStatus(value: "Done", caption: "9 today"))
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 8, met: true)) == CardStatus(value: "Done", caption: "today"))
    }

    @Test func exactlyAboveTargetDoesNotShowTheCount() {
        let r = rules(.do, .exactly, 1, .monthly)
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 2, met: true)) == CardStatus(value: "Done", caption: "this month"))
    }

    @Test func noLimitShowsTheCount() {
        let r = rules(.do, .noLimit)
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 4)) == CardStatus(value: "4", caption: "today, no limit"))
    }

    @Test func avoidIsClearWhileZero() {
        let r = rules(.avoid, .atMost, 0, .weekly)
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 0, met: true)) == CardStatus(value: "0", caption: "clear this week"))
        #expect(CardStatusFormatter.progress(rules: r, snapshot: snapshot(count: 2)) == CardStatus(value: "2", caption: "this week"))
    }

    @Test func averageAndStreakLines() {
        let r = rules(.do, .exactly, 1, .weekly)
        #expect(CardStatusFormatter.status(rules: r, snapshot: snapshot(count: 0, avg30: 0.724), stat: .avg30) == CardStatus(value: "72%", caption: "30-day average"))
        #expect(CardStatusFormatter.status(rules: r, snapshot: snapshot(count: 0), stat: .avg90) == CardStatus(value: "–", caption: "90-day average"))
        #expect(CardStatusFormatter.status(rules: r, snapshot: snapshot(count: 0, streak: 1), stat: .streak) == CardStatus(value: "1", caption: "week streak"))
        #expect(CardStatusFormatter.status(rules: r, snapshot: snapshot(count: 0, streak: 5), stat: .streak) == CardStatus(value: "5", caption: "weeks streak"))
    }

    @Test func tapCyclesThroughTheAvailableStats() {
        let scored = rules(.do, .exactly, 1)
        #expect(CardStatusFormatter.availableStats(rules: scored, streakEmphasis: true) == [.progress, .avg30, .avg90, .streak])
        #expect(CardStatusFormatter.nextStat(after: .streak, rules: scored, streakEmphasis: true) == .progress)
        // The streak is skipped when streaks are not emphasised.
        #expect(CardStatusFormatter.nextStat(after: .avg90, rules: scored, streakEmphasis: false) == .progress)
        // No-limit tasks have no averages.
        #expect(CardStatusFormatter.availableStats(rules: rules(.do, .noLimit), streakEmphasis: true) == [.progress, .streak])
        #expect(CardStatusFormatter.availableStats(rules: rules(.avoid, .noLimit), streakEmphasis: true) == [.progress])
        // A saved stat that is no longer available falls back to progress.
        #expect(CardStatusFormatter.shownStat(.avg30, rules: rules(.do, .noLimit), streakEmphasis: true) == .progress)
    }

    @Test func goalSummaries() {
        #expect(CardStatusFormatter.summary(rules: rules(.do, .exactly, 1)) == "Daily, once")
        #expect(CardStatusFormatter.summary(rules: rules(.do, .exactly, 3)) == "Daily, 3 times")
        #expect(CardStatusFormatter.summary(rules: rules(.do, .atLeast, 8, .weekly)) == "Weekly, at least 8 times")
        #expect(CardStatusFormatter.summary(rules: rules(.avoid, .atMost, 0)) == "Daily, none allowed")
        #expect(CardStatusFormatter.summary(rules: rules(.avoid, .atMost, 2, .monthly)) == "Monthly, at most 2")
        #expect(CardStatusFormatter.summary(rules: rules(.do, .noLimit)) == "Daily, no limit")
    }
}
