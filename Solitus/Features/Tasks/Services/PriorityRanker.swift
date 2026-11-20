import Foundation

/// What the ranker needs to know about one task.
nonisolated struct RankInput: Sendable {
    var id: UUID
    var rules: TaskRules
    var slots: [SlotRule]
    var pinWhenLogged: Bool
    var sortOrder: Int
    /// The count of the current period.
    var periodCount: Int
    /// The current streak, for the "streak at risk" boost.
    var currentStreak: Int

    init(
        id: UUID = UUID(),
        rules: TaskRules,
        slots: [SlotRule] = [],
        pinWhenLogged: Bool = true,
        sortOrder: Int = 0,
        periodCount: Int = 0,
        currentStreak: Int = 0
    ) {
        self.id = id
        self.rules = rules
        self.slots = slots
        self.pinWhenLogged = pinWhenLogged
        self.sortOrder = sortOrder
        self.periodCount = periodCount
        self.currentStreak = currentStreak
    }
}

/// The five groups of the Track screen, top to bottom (DESIGN.md 6.9).
nonisolated enum TrackGroup: Int, Comparable, Sendable {
    /// Logged Avoid tasks with `pinWhenLogged` on.
    case loggedAvoid = 1
    /// Do tasks with a target, not yet met.
    case unmet = 2
    /// No-limit Do tasks.
    case noLimit = 3
    /// Clear Avoid tasks, plus logged Avoid tasks with pinning off.
    case quietAvoid = 4
    /// Met tasks, dimmed.
    case met = 5

    static func < (lhs: TrackGroup, rhs: TrackGroup) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated struct RankedTask: Hashable, Sendable {
    let id: UUID
    let group: TrackGroup
    /// Only meaningful in the `unmet` group; zero elsewhere.
    let urgency: Double
}

/// Track order (DESIGN.md 6.9). Every number is a named constant below.
nonisolated struct PriorityRanker: Sendable {
    // OPEN: 12.13 the whole ordering is a v1 proposal. Tune the numbers here.

    // Daily tasks
    static let overdueBase = 3.0
    static let overdueExtraMax = 1.0
    static let overdueFullAfterMinutes = 24 * 60
    static let soonUrgency = 2.0
    static let soonWindowMinutes = 120
    static let noSlotUrgency = 1.0
    // Weekly and monthly tasks
    static let behindUrgency = 4.0
    static let mustActTodayUrgency = 3.0
    static let preferredDayUrgency = 2.5
    // Streaks
    static let streakBoost = 0.5
    static let streakBoostMinimum = 3

    let scores: ScoreCalculator
    let streakPriorityBoost: Bool

    init(scores: ScoreCalculator = ScoreCalculator(), streakPriorityBoost: Bool = true) {
        self.scores = scores
        self.streakPriorityBoost = streakPriorityBoost
    }

    /// Sorts tasks for Track. `minutesNow` is minutes after local midnight.
    func rank(_ inputs: [RankInput], today: DayKey, minutesNow: Int) -> [RankedTask] {
        let keyed = inputs.map { input -> (task: RankedTask, sortOrder: Int, touched: Bool) in
            let group = self.group(for: input)
            let urgency = group == .unmet ? self.urgency(for: input, today: today, minutesNow: minutesNow) : 0
            return (RankedTask(id: input.id, group: group, urgency: urgency), input.sortOrder, input.periodCount > 0)
        }
        let sorted = keyed.sorted { a, b in
            if a.task.group != b.task.group {
                return a.task.group < b.task.group
            }
            if a.task.group == .unmet && a.task.urgency != b.task.urgency {
                return a.task.urgency > b.task.urgency
            }
            if a.task.group == .noLimit && a.touched != b.touched {
                // Untouched no-limit tasks sit above ones already logged.
                return !a.touched
            }
            return a.sortOrder < b.sortOrder
        }
        return sorted.map { $0.task }
    }

    /// Which of the five groups a task belongs to.
    ///
    /// Every Avoid task, with or without a limit, is in `loggedAvoid` or
    /// `quietAvoid`; the `noLimit` group holds no-limit Do tasks.
    func group(for input: RankInput) -> TrackGroup {
        let rules = input.rules
        switch rules.kind {
        case .avoid:
            return (input.periodCount > 0 && input.pinWhenLogged) ? .loggedAvoid : .quietAvoid
        case .do:
            if !rules.isScored {
                return .noLimit
            }
            return scores.isMet(rules, count: input.periodCount) ? .met : .unmet
        }
    }

    /// Urgency of an unmet Do task with a target: the sum of the components
    /// in the table in DESIGN.md 6.9.
    func urgency(for input: RankInput, today: DayKey, minutesNow: Int) -> Double {
        var value: Double
        switch input.rules.period {
        case .daily:
            value = dailyUrgency(for: input, minutesNow: minutesNow)
        case .weekly, .monthly:
            value = longPeriodUrgency(for: input, today: today)
        }
        if streakPriorityBoost && input.currentStreak >= PriorityRanker.streakBoostMinimum {
            // Streak at risk: a streak of 3 or more and the period unmet.
            value += PriorityRanker.streakBoost
        }
        return value
    }

    private func dailyUrgency(for input: RankInput, minutesNow: Int) -> Double {
        // The next unmet slot is the one whose index equals the count so far.
        let timed = input.slots
            .filter { $0.minutes != nil }
            .sorted { $0.index < $1.index }
        guard input.periodCount >= 0, input.periodCount < timed.count,
              let slotMinutes = timed[input.periodCount].minutes
        else {
            return PriorityRanker.noSlotUrgency
        }

        let untilSlot = slotMinutes - minutesNow
        if untilSlot <= 0 {
            // Overdue: 3, plus up to 1 as the time overdue approaches 24 hours.
            let overdue = Double(-untilSlot) / Double(PriorityRanker.overdueFullAfterMinutes)
            return PriorityRanker.overdueBase + PriorityRanker.overdueExtraMax * min(overdue, 1)
        }
        if untilSlot <= PriorityRanker.soonWindowMinutes {
            return PriorityRanker.soonUrgency
        }
        // Later today: between 0 and 1, rising as the time approaches.
        let range = Double(24 * 60 - PriorityRanker.soonWindowMinutes)
        let distance = Double(untilSlot - PriorityRanker.soonWindowMinutes)
        return min(max(1 - distance / range, 0), 1)
    }

    private func longPeriodUrgency(for input: RankInput, today: DayKey) -> Double {
        let rules = input.rules
        let span = scores.periods.span(containing: today, period: rules.period)
        let daysLeft = today.days(until: span.end) + 1   // today counts
        let remaining = max(rules.doTarget - input.periodCount, 0)

        if remaining > daysLeft {
            return PriorityRanker.behindUrgency
        }
        if remaining == daysLeft {
            return PriorityRanker.mustActTodayUrgency
        }
        if input.slots.contains(where: { $0.matches(today, period: rules.period) }) {
            return PriorityRanker.preferredDayUrgency
        }
        return Double(remaining) / Double(max(daysLeft, 1))
    }
}
