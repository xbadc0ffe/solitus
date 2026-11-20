import Foundation

/// One point of a running-average series. `value` is nil when no day in the
/// window had a value; the UI shows a dash or a gap.
nonisolated struct RunningAveragePoint: Hashable, Sendable {
    let day: DayKey
    let value: Double?
}

/// Running averages (DESIGN.md 6.5).
///
/// `RA(W, d)` is the mean of the daily values from day `d - W + 1` to day
/// `d`. Days with no value are skipped. If no day in the window has a value
/// the average is undefined (nil).
nonisolated struct RunningAverage: Sendable {
    static let shortWindow = 30
    static let longWindow = 90

    let scores: ScoreCalculator

    init(scores: ScoreCalculator = ScoreCalculator()) {
        self.scores = scores
    }

    // MARK: Generic forms

    /// `RA(window, day)` over any per-day value.
    func average(window: Int, endingOn day: DayKey, value: (DayKey) -> Double?) -> Double? {
        var sum = 0.0
        var used = 0
        for offset in 0..<max(window, 1) {
            if let v = value(day.adding(-offset)) {
                sum += v
                used += 1
            }
        }
        return used > 0 ? sum / Double(used) : nil
    }

    /// `RA(window, d)` for every day `d` from `first` to `last`, so every
    /// point is the average of the `window` days ending on that day.
    func series(window: Int, from first: DayKey, to last: DayKey, value: (DayKey) -> Double?) -> [RunningAveragePoint] {
        guard first <= last else { return [] }
        let width = max(window, 1)
        let start = first.adding(-(width - 1))
        let total = start.days(until: last) + 1

        // Each day's value is computed once, then a window slides over them.
        var values: [Double?] = []
        values.reserveCapacity(total)
        for offset in 0..<total {
            values.append(value(start.adding(offset)))
        }

        var points: [RunningAveragePoint] = []
        points.reserveCapacity(first.days(until: last) + 1)
        var sum = 0.0
        var used = 0
        for index in 0..<total {
            if let entering = values[index] {
                sum += entering
                used += 1
            }
            if index >= width, let leaving = values[index - width] {
                sum -= leaving
                used -= 1
            }
            if index >= width - 1 {
                let average: Double? = used > 0 ? sum / Double(used) : nil
                points.append(RunningAveragePoint(day: start.adding(index), value: average))
            }
        }
        return points
    }

    // MARK: Per task

    /// A task's `RA(window, day)`. Nil for no-limit tasks.
    func average(for history: TaskHistory, window: Int, endingOn day: DayKey, today: DayKey) -> Double? {
        average(window: window, endingOn: day) { d in
            scores.dailyValue(history.rules, counts: history.counts, day: d, today: today)
        }
    }

    /// A task's running-average line for the trend graph.
    func series(for history: TaskHistory, window: Int, from first: DayKey, to last: DayKey, today: DayKey) -> [RunningAveragePoint] {
        series(window: window, from: first, to: last) { d in
            scores.dailyValue(history.rules, counts: history.counts, day: d, today: today)
        }
    }

    // MARK: Fill colour

    /// Where a running average sits on the heat ramp: `min(RA / fullAt, 1)`.
    /// At the default `fullAt` of 0.85, anything at or above 85% is at
    /// maximum.
    static func fillLevel(average: Double, fullAt: Double) -> Double {
        guard fullAt > 0 else { return average > 0 ? 1 : 0 }
        return min(max(average / fullAt, 0), 1)
    }
}
