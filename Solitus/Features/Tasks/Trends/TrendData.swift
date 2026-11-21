import Foundation

/// One line of the running-average graph (DESIGN.md 7.5 and 7.6).
nonisolated struct TrendLine: Identifiable, Sendable {
    enum Kind: Hashable, Sendable {
        case total, best, worst
        /// A single task's line added on the trend sheet; the number picks
        /// its colour and dash pattern.
        case task(Int)
    }

    let id: String
    let name: String
    let kind: Kind
    let points: [RunningAveragePoint]

    /// Today's value, shown in the legend.
    var current: Double? { points.last?.value }

    static let totalID = "total"
    static let bestID = "best"
    static let worstID = "worst"
}

/// Builds the graph's lines from task histories. Pure values in and out.
nonisolated struct TrendData: Sendable {
    /// The graph never reaches further back than this many days.
    static let maxHistoryDays = 730

    let calc: TaskCalc
    let today: DayKey

    /// The first day the graph can scroll back to: the earliest scored
    /// task's first day, but always at least one window before today.
    func firstDay(_ histories: [TaskHistory], window: Int) -> DayKey {
        let earliest = calc.trends.eligible(histories).map(\.rules.createdDay).min() ?? today
        let oldest = today.adding(-TrendData.maxHistoryDays)
        let windowStart = today.adding(-(max(window, 1) - 1))
        return min(max(earliest, oldest), windowStart)
    }

    /// Total, Best K and Worst K (DESIGN.md 6.6).
    func defaultLines(_ histories: [TaskHistory], window: Int, groupSize: Int) -> [TrendLine] {
        let eligible = calc.trends.eligible(histories)
        let first = firstDay(histories, window: window)
        let groups = calc.trends.groups(histories, window: window, today: today, groupSize: groupSize)
        let best = eligible.filter { groups.best.contains($0.id) }
        let worst = eligible.filter { groups.worst.contains($0.id) }

        func line(_ id: String, _ name: String, _ kind: TrendLine.Kind, _ members: [TaskHistory]) -> TrendLine {
            TrendLine(
                id: id,
                name: name,
                kind: kind,
                points: calc.trends.meanSeries(members, window: window, from: first, to: today, today: today)
            )
        }
        return [
            line(TrendLine.totalID, "Total", .total, eligible),
            line(TrendLine.bestID, "Best \(groupSize)", .best, best),
            line(TrendLine.worstID, "Worst \(groupSize)", .worst, worst),
        ]
    }

    /// One task's own line.
    func taskLine(_ history: TaskHistory, index: Int, window: Int, first: DayKey) -> TrendLine {
        TrendLine(
            id: history.id.uuidString,
            name: history.name,
            kind: .task(index),
            points: calc.averages.series(for: history, window: window, from: first, to: today, today: today)
        )
    }

    /// A sentence for VoiceOver: each line's name and today's value.
    static func summary(_ lines: [TrendLine]) -> String {
        lines.map { "\($0.name) \(CardStatusFormatter.percent($0.current))" }.joined(separator: ", ")
    }
}

/// What the trend sheet remembers between openings (DESIGN.md 7.6): which
/// of the three default lines are switched off, and which tasks were added.
nonisolated struct TrendSheetState: Codable, Hashable, Sendable {
    var hidden: [String] = []
    var taskIDs: [UUID] = []

    init() {}

    init(json: String) {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TrendSheetState.self, from: data)
        else { return }
        self = decoded
    }

    var json: String {
        guard let data = try? JSONEncoder().encode(self), let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }
}
