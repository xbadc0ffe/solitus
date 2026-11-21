import Foundation

/// The numbers a screen needs about one task right now.
nonisolated struct TaskSnapshot: Hashable, Sendable {
    /// The count of the current period (today, this week, this month).
    var periodCount: Int
    /// Today's own count.
    var todayCount: Int
    /// Whether the current period has met the goal (DESIGN.md 6.2).
    var isMet: Bool
    /// `RA(30, today)` and `RA(90, today)`; nil for no-limit tasks.
    var average30: Double?
    var average90: Double?
    var streak: StreakSummary
}

/// The calculation services for one week-start setting, built together so
/// screens do not assemble them one by one.
nonisolated struct TaskCalc: Sendable {
    let periods: PeriodCalculator
    let scores: ScoreCalculator
    let averages: RunningAverage
    let streaks: StreakCalculator
    let heat: HeatCalculator
    let trends: TrendAggregator

    init(weekStart: Int = 1) {
        let periods = PeriodCalculator(weekStart: weekStart)
        let scores = ScoreCalculator(periods: periods)
        self.periods = periods
        self.scores = scores
        self.averages = RunningAverage(scores: scores)
        self.streaks = StreakCalculator(scores: scores)
        self.heat = HeatCalculator(scores: scores)
        self.trends = TrendAggregator(scores: scores)
    }

    func snapshot(_ history: TaskHistory, today: DayKey) -> TaskSnapshot {
        let count = periods.count(containing: today, period: history.rules.period, counts: history.counts)
        return TaskSnapshot(
            periodCount: count,
            todayCount: history.counts[today] ?? 0,
            isMet: scores.isMet(history.rules, count: count),
            average30: averages.average(for: history, window: RunningAverage.shortWindow, endingOn: today, today: today),
            average90: averages.average(for: history, window: RunningAverage.longWindow, endingOn: today, today: today),
            streak: streaks.summary(for: history, today: today)
        )
    }
}
