import Foundation

/// A task's streak numbers, counted in the task's own periods.
nonisolated struct StreakSummary: Hashable, Sendable {
    /// Met periods counting back from now.
    var current: Int
    /// The longest streak ever.
    var best: Int
    /// The mean length of all streaks of length 1 or more, including the
    /// current one. Zero when there has never been a streak.
    var average: Double

    static let none = StreakSummary(current: 0, best: 0, average: 0)
}

/// Streaks (DESIGN.md 6.7).
nonisolated struct StreakCalculator: Sendable {
    let scores: ScoreCalculator

    init(scores: ScoreCalculator = ScoreCalculator()) {
        self.scores = scores
    }

    /// Whether a period counts toward a streak, or nil if the task has
    /// nothing to meet.
    ///
    /// Scored tasks follow 6.2. A no-limit Do task's period is met when its
    /// count is at least 1. A no-limit Avoid task has no streak.
    func isPeriodMet(_ rules: TaskRules, count: Int) -> Bool? {
        if rules.isScored {
            return scores.isMet(rules, count: count)
        }
        switch rules.kind {
        case .do: return count >= 1
        case .avoid: return nil
        }
    }

    func summary(for history: TaskHistory, today: DayKey) -> StreakSummary {
        let rules = history.rules
        guard rules.createdDay <= today, isPeriodMet(rules, count: 0) != nil else {
            return .none
        }

        let periods = scores.periods
        let allowedGap = max(rules.streakGap, 0)

        var finished: [Int] = []   // lengths of streaks that have ended
        var length = 0             // the streak being built
        var gapRun = 0             // consecutive unmet periods inside it

        var span = periods.span(containing: rules.createdDay, period: rules.period)
        while span.start <= today {
            let count = periods.count(in: span, counts: history.counts)
            let met = isPeriodMet(rules, count: count) ?? false
            let isCurrent = span.contains(today)

            if met {
                length += 1
                gapRun = 0
            } else if isCurrent && rules.kind == .do {
                // The current period is not yet met. It does not break the
                // streak until it ends, and it adds nothing.
            } else if length > 0 {
                // An unmet period. (For an Avoid task this includes a current
                // period that is already over its limit: it cannot recover.)
                // Up to `allowedGap` in a row are forgiven and add nothing.
                gapRun += 1
                if gapRun > allowedGap {
                    finished.append(length)
                    length = 0
                    gapRun = 0
                }
            }
            span = periods.next(after: span, period: rules.period)
        }

        var all = finished
        if length > 0 {
            all.append(length)
        }
        guard !all.isEmpty else { return .none }

        let total = all.reduce(0, +)
        return StreakSummary(
            current: length,
            best: all.max() ?? 0,
            average: Double(total) / Double(all.count)
        )
    }
}
