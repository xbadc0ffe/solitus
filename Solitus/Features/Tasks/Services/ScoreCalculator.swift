import Foundation

/// Goal status, period score and per-day value (DESIGN.md 6.2 to 6.4).
nonisolated struct ScoreCalculator: Sendable {
    let periods: PeriodCalculator

    init(periods: PeriodCalculator = PeriodCalculator()) {
        self.periods = periods
    }

    // MARK: 6.2 Goal and status

    /// Whether a period with this count has met the task's goal.
    ///
    /// - Do, exactly N or at least N: count has reached N.
    /// - Avoid, at most N: count is within N.
    /// - No limit: never met; these tasks are not scored.
    ///
    /// "Exactly N" is treated as "reached N". A count above N cannot be
    /// logged (see `EntryStore`), and can only appear if the target is
    /// lowered later; such a period still counts as met.
    func isMet(_ rules: TaskRules, count: Int) -> Bool {
        guard rules.isScored else { return false }
        switch rules.kind {
        case .do: return count >= rules.doTarget
        case .avoid: return count <= rules.avoidLimit
        }
    }

    // MARK: 6.3 Score

    /// A period's score from 0 to 1, or nil for no-limit tasks.
    ///
    /// - Do with a target: `min(count / N, 1)`.
    /// - Avoid with a limit: 1 if `count <= N`, otherwise 0.
    func score(_ rules: TaskRules, count: Int) -> Double? {
        guard rules.isScored else { return nil }
        switch rules.kind {
        case .do:
            return min(Double(max(count, 0)) / Double(rules.doTarget), 1)
        case .avoid:
            return count <= rules.avoidLimit ? 1 : 0
        }
    }

    // MARK: 6.4 Daily value (v1 proposal)

    /// The value of one day, used by averages and heat.
    ///
    /// - Daily task: that day's score.
    /// - Weekly or monthly task: the score of the period containing the day.
    /// - Current, unfinished weekly or monthly period, Do: pace so far,
    ///   `min(1, count / max(1, ceil(N * daysElapsed / daysInPeriod)))`.
    /// - Current, unfinished period, Avoid: 1 while within the limit, else 0.
    /// - Days before the task was created, days after today, and no-limit
    ///   tasks have no value.
    // OPEN: 12.13 the daily value for weekly and monthly tasks is a v1
    // proposal to tune on a device.
    func dailyValue(_ rules: TaskRules, counts: DayCounts, day: DayKey, today: DayKey) -> Double? {
        guard rules.isScored, day >= rules.createdDay, day <= today else { return nil }

        if rules.period == .daily {
            return score(rules, count: counts[day] ?? 0)
        }

        let span = periods.span(containing: day, period: rules.period)
        let count = periods.count(in: span, counts: counts)
        let isCurrent = span.contains(today)

        guard isCurrent, rules.kind == .do else {
            // A finished period, or an Avoid task (whose rule is the same
            // whether or not the period has ended).
            return score(rules, count: count)
        }

        let daysElapsed = span.start.days(until: today) + 1
        let expected = (Double(rules.doTarget) * Double(daysElapsed) / Double(span.dayCount)).rounded(.up)
        return min(1, Double(max(count, 0)) / max(1, expected))
    }
}
