import Foundation

/// One day's heat.
nonisolated struct HeatValue: Hashable, Sendable {
    /// `a(d)`: the day's amount, 0 to 1.
    let amount: Double
    /// `m(d)`: momentum carried from earlier days.
    let momentum: Double
    /// `k(d)`: the heat itself, 0 to 1. Continuous uses (the year view's
    /// bloom) read this.
    let heat: Double
    /// `round(k * 5)`: 0 to 5, an index into the ramp in DESIGN.md 9.3.
    let step: Int
}

/// Heat (DESIGN.md 6.8). One value per day combines that day's amount with
/// recent momentum, so a single day after a long gap is only warm.
///
/// ```
/// m(d) = 0.55 * m(d-1) + 0.45 * a(d)   momentum
/// k(d) = 0.6 * a(d) + 0.4 * m(d)       heat
/// step = round(k * 5)
/// ```
nonisolated struct HeatCalculator: Sendable {
    // OPEN: 12.13 the weights are a v1 proposal (DESIGN.md 6.8). Tune them
    // here.
    static let momentumCarry = 0.55
    static let momentumGain = 0.45
    static let amountWeight = 0.6
    static let momentumWeight = 0.4
    /// The top step of the ramp; steps run from 0 to this.
    static let maxStep = 5
    /// Automatic `heatMax` looks at the largest daily count in this many days.
    static let autoHeatMaxWindow = 90
    /// Automatic `heatMax` is never below this.
    static let autoHeatMaxFloor = 3

    let scores: ScoreCalculator

    init(scores: ScoreCalculator = ScoreCalculator()) {
        self.scores = scores
    }

    // MARK: Core recurrence

    /// Heat for every day from `first` to `last` that has an amount.
    ///
    /// Momentum before the first day with an amount equals that day's
    /// amount. Days with no amount are left out and do not change momentum.
    func heat(from first: DayKey, to last: DayKey, amount: (DayKey) -> Double?) -> [DayKey: HeatValue] {
        guard first <= last else { return [:] }
        var result: [DayKey: HeatValue] = [:]
        var previousMomentum: Double?
        var day = first
        while day <= last {
            if let raw = amount(day) {
                let a = min(max(raw, 0), 1)
                let carried = previousMomentum ?? a
                let m = HeatCalculator.momentumCarry * carried + HeatCalculator.momentumGain * a
                let k = HeatCalculator.amountWeight * a + HeatCalculator.momentumWeight * m
                result[day] = HeatValue(amount: a, momentum: m, heat: k, step: HeatCalculator.step(for: k))
                previousMomentum = m
            }
            day = day.adding(1)
        }
        return result
    }

    static func step(for heat: Double) -> Int {
        let raw = Int((heat * Double(maxStep)).rounded())
        return min(max(raw, 0), maxStep)
    }

    // MARK: Per task

    /// The top of the count-based heat scale: the task's own `heatMax`, or
    /// automatically the largest daily count in the last 90 days with a
    /// floor of 3.
    func heatMax(for history: TaskHistory, today: DayKey) -> Int {
        if let fixed = history.rules.heatMax, fixed > 0 {
            return fixed
        }
        var largest = 0
        for offset in 0..<HeatCalculator.autoHeatMaxWindow {
            largest = max(largest, history.counts[today.adding(-offset)] ?? 0)
        }
        return max(largest, HeatCalculator.autoHeatMaxFloor)
    }

    /// `a(d)` for one task, or nil before it was created and after today.
    ///
    /// - Do task with a target: the daily value (6.4).
    /// - No-limit task: `min(count / heatMax, 1)`.
    /// - Avoid task: `min(count / heatMax, 1)`, so heat shows occurrences.
    func amount(for history: TaskHistory, day: DayKey, today: DayKey, heatMax: Int) -> Double? {
        let rules = history.rules
        guard day >= rules.createdDay, day <= today else { return nil }

        if rules.kind == .do && rules.isScored {
            return scores.dailyValue(rules, counts: history.counts, day: day, today: today)
        }
        // OPEN: 12.1 heat for Avoid tasks means occurrences (hot is bad) and
        // uses the same ramp. No-limit tasks use the same count-based scale.
        let count = history.counts[day] ?? 0
        return min(Double(max(count, 0)) / Double(max(heatMax, 1)), 1)
    }

    /// Heat for every day of a task's life up to today. Always computed from
    /// the task's first day so momentum is right for whichever month is on
    /// screen.
    func heat(for history: TaskHistory, today: DayKey) -> [DayKey: HeatValue] {
        let top = heatMax(for: history, today: today)
        return heat(from: history.rules.createdDay, to: today) { day in
            amount(for: history, day: day, today: today, heatMax: top)
        }
    }

    // MARK: All tasks

    /// All-tasks heat for Trends: `a(d)` is the mean daily value across
    /// scored, unarchived tasks. Days on which no task has a value are left
    /// out.
    func allTasksHeat(_ histories: [TaskHistory], today: DayKey) -> [DayKey: HeatValue] {
        let scored = histories.filter { $0.rules.isScored && !$0.rules.isArchived }
        guard let first = scored.map({ $0.rules.createdDay }).min() else { return [:] }
        return heat(from: first, to: today) { day in
            var sum = 0.0
            var used = 0
            for history in scored {
                if let value = scores.dailyValue(history.rules, counts: history.counts, day: day, today: today) {
                    sum += value
                    used += 1
                }
            }
            return used > 0 ? sum / Double(used) : nil
        }
    }
}
