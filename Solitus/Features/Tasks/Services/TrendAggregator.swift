import Foundation

/// The best and worst groups for the selected window (DESIGN.md 6.6).
nonisolated struct TrendGroups: Hashable, Sendable {
    /// Highest running average first.
    var best: [UUID]
    /// Lowest running average first.
    var worst: [UUID]
}

/// One row of the Top streaks list.
nonisolated struct StreakRanking: Hashable, Sendable {
    let id: UUID
    let name: String
    let current: Int
}

/// Trends aggregates (DESIGN.md 6.6). Everything here is computed over
/// scored, unarchived tasks.
nonisolated struct TrendAggregator: Sendable {
    static let topStreakCount = 3

    let averages: RunningAverage
    let streaks: StreakCalculator

    init(scores: ScoreCalculator = ScoreCalculator()) {
        self.averages = RunningAverage(scores: scores)
        self.streaks = StreakCalculator(scores: scores)
    }

    /// The tasks that take part in averages and groups.
    func eligible(_ histories: [TaskHistory]) -> [TaskHistory] {
        histories.filter { $0.rules.isScored && !$0.rules.isArchived }
    }

    /// Total average: the mean of the tasks' running averages on `day`.
    /// Tasks whose average is undefined on that day are skipped.
    func totalAverage(_ histories: [TaskHistory], window: Int, endingOn day: DayKey, today: DayKey) -> Double? {
        let values = eligible(histories).compactMap {
            averages.average(for: $0, window: window, endingOn: day, today: today)
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Ranks tasks by today's `RA(window, today)` and takes the top K and
    /// the bottom K, where K is `min(groupSize, taskCount)`. Tasks with an
    /// undefined average are left out. Ties keep the input order.
    ///
    /// Membership is fixed by today's ranking so the group lines are
    /// continuous across the graph.
    // OPEN: 12.2 with few tasks both groups contain every task and the three
    // lines coincide. Accepted for now.
    func groups(_ histories: [TaskHistory], window: Int, today: DayKey, groupSize: Int) -> TrendGroups {
        var ranked: [(id: UUID, value: Double, order: Int)] = []
        for (order, history) in eligible(histories).enumerated() {
            if let value = averages.average(for: history, window: window, endingOn: today, today: today) {
                ranked.append((history.id, value, order))
            }
        }
        let size = min(max(groupSize, 0), ranked.count)
        let descending = ranked.sorted { a, b in
            a.value != b.value ? a.value > b.value : a.order < b.order
        }
        let ascending = ranked.sorted { a, b in
            a.value != b.value ? a.value < b.value : a.order < b.order
        }
        return TrendGroups(
            best: descending.prefix(size).map { $0.id },
            worst: ascending.prefix(size).map { $0.id }
        )
    }

    /// A line for the trend graph: on every day from `first` to `last`, the
    /// mean of the given tasks' running averages. Pass every eligible task
    /// for the Total line, or a group's members for a group line.
    func meanSeries(_ histories: [TaskHistory], window: Int, from first: DayKey, to last: DayKey, today: DayKey) -> [RunningAveragePoint] {
        guard first <= last else { return [] }
        let lines = histories.map {
            averages.series(for: $0, window: window, from: first, to: last, today: today)
        }
        let dayCount = first.days(until: last) + 1
        var points: [RunningAveragePoint] = []
        points.reserveCapacity(dayCount)
        for index in 0..<dayCount {
            var sum = 0.0
            var used = 0
            for line in lines where index < line.count {
                if let value = line[index].value {
                    sum += value
                    used += 1
                }
            }
            let mean: Double? = used > 0 ? sum / Double(used) : nil
            points.append(RunningAveragePoint(day: first.adding(index), value: mean))
        }
        return points
    }

    /// Top streaks: the longest current streaks among unarchived tasks,
    /// longest first. Tasks with no current streak are left out.
    func topStreaks(_ histories: [TaskHistory], today: DayKey, limit: Int = TrendAggregator.topStreakCount) -> [StreakRanking] {
        var rankings: [(ranking: StreakRanking, order: Int)] = []
        for (order, history) in histories.enumerated() where !history.rules.isArchived {
            let current = streaks.summary(for: history, today: today).current
            if current > 0 {
                rankings.append((StreakRanking(id: history.id, name: history.name, current: current), order))
            }
        }
        let sorted = rankings.sorted { a, b in
            a.ranking.current != b.ranking.current ? a.ranking.current > b.ranking.current : a.order < b.order
        }
        return sorted.prefix(max(limit, 0)).map { $0.ranking }
    }
}
