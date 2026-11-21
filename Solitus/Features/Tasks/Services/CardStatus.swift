import Foundation

/// The status line of a task card: a large value and a small caption beside
/// it (DESIGN.md 7.2).
nonisolated struct CardStatus: Hashable, Sendable {
    var value: String
    var caption: String
}

/// Words and numbers for task cards. Pure text, so it can be tested.
nonisolated enum CardStatusFormatter {
    /// Shown where a number is undefined (DESIGN.md 6.5).
    static let dash = "–"

    static func periodName(_ period: TaskPeriod) -> String {
        switch period {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    /// "today", "this week" or "this month".
    static func periodCaption(_ period: TaskPeriod) -> String {
        switch period {
        case .daily: return "today"
        case .weekly: return "this week"
        case .monthly: return "this month"
        }
    }

    /// "day", "week" or "month", with an "s" unless `count` is 1.
    static func periodUnit(_ period: TaskPeriod, count: Int) -> String {
        let unit: String
        switch period {
        case .daily: unit = "day"
        case .weekly: unit = "week"
        case .monthly: unit = "month"
        }
        return count == 1 ? unit : unit + "s"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return dash }
        return "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    /// The stats a card can cycle through, in order. Averages are left out
    /// for no-limit tasks, which have none. The streak is left out when
    /// streaks are not emphasised (DESIGN.md 8.1) and for no-limit Avoid
    /// tasks, which have no streak.
    static func availableStats(rules: TaskRules, streakEmphasis: Bool) -> [QuickStat] {
        var stats: [QuickStat] = [.progress]
        if rules.isScored {
            stats.append(contentsOf: [.avg30, .avg90])
        }
        if streakEmphasis && (rules.isScored || rules.kind == .do) {
            stats.append(.streak)
        }
        return stats
    }

    /// The stat to show: the saved one if it is available, else progress.
    static func shownStat(_ saved: QuickStat, rules: TaskRules, streakEmphasis: Bool) -> QuickStat {
        availableStats(rules: rules, streakEmphasis: streakEmphasis).contains(saved) ? saved : .progress
    }

    /// The stat a tap moves to.
    static func nextStat(after current: QuickStat, rules: TaskRules, streakEmphasis: Bool) -> QuickStat {
        let stats = availableStats(rules: rules, streakEmphasis: streakEmphasis)
        guard let index = stats.firstIndex(of: current) else { return .progress }
        return stats[(index + 1) % stats.count]
    }

    static func status(rules: TaskRules, snapshot: TaskSnapshot, stat: QuickStat) -> CardStatus {
        switch stat {
        case .progress:
            return progress(rules: rules, snapshot: snapshot)
        case .avg30:
            return CardStatus(value: percent(snapshot.average30), caption: "30-day average")
        case .avg90:
            return CardStatus(value: percent(snapshot.average90), caption: "90-day average")
        case .streak:
            let current = snapshot.streak.current
            return CardStatus(value: String(current), caption: periodUnit(rules.period, count: current) + " streak")
        }
    }

    /// The progress line from the table in DESIGN.md 6.2 and 7.2.
    static func progress(rules: TaskRules, snapshot: TaskSnapshot) -> CardStatus {
        let count = snapshot.periodCount
        let when = periodCaption(rules.period)
        guard rules.isScored else {
            return CardStatus(value: String(count), caption: when + ", no limit")
        }
        switch rules.kind {
        case .do:
            if snapshot.isMet {
                // "At least" keeps counting past the target.
                let extra = rules.goalMode == .atLeast && count > rules.doTarget ? "\(count) " : ""
                return CardStatus(value: "Done", caption: extra + when)
            }
            return CardStatus(value: "\(count)/\(rules.doTarget)", caption: when)
        case .avoid:
            return CardStatus(value: String(count), caption: count == 0 ? "clear " + when : when)
        }
    }

    /// One line describing a task's goal, for the Tasks list:
    /// "Daily, 3 times", "Weekly, at most 2", "Daily, no limit".
    static func summary(rules: TaskRules) -> String {
        let period = periodName(rules.period)
        switch rules.goalMode {
        case .noLimit:
            return period + ", no limit"
        case .exactly:
            return period + ", " + times(rules.doTarget)
        case .atLeast:
            return period + ", at least " + times(rules.doTarget)
        case .atMost:
            return rules.avoidLimit == 0 ? period + ", none allowed" : period + ", at most \(rules.avoidLimit)"
        }
    }

    private static func times(_ count: Int) -> String {
        count == 1 ? "once" : "\(count) times"
    }
}
