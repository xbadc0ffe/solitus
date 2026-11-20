import Foundation

/// Counts per day for one task. Days with nothing logged are absent.
typealias DayCounts = [DayKey: Int]

/// The parts of a task that the calculation services need, as a plain value.
///
/// Services in `Features/Tasks/Services` work on `TaskRules`, `SlotRule` and
/// `TaskHistory` rather than on the SwiftData models. That keeps every rule
/// in DESIGN.md section 6 testable without a model container, and lets the
/// values cross actors freely.
nonisolated struct TaskRules: Hashable, Sendable {
    var kind: TaskKind
    var period: TaskPeriod
    var goalMode: GoalMode
    /// N. Ignored for `noLimit`.
    var target: Int
    /// The first day that has a value. Earlier days are skipped everywhere.
    var createdDay: DayKey
    /// Periods a streak may skip (DESIGN.md 6.7).
    var streakGap: Int
    /// Running average that counts as full (DESIGN.md 6.5).
    var fullAt: Double
    /// Top of the heat scale for count-based heat; nil means automatic.
    var heatMax: Int?
    var isArchived: Bool

    init(
        kind: TaskKind = .do,
        period: TaskPeriod = .daily,
        goalMode: GoalMode = .exactly,
        target: Int = 1,
        createdDay: DayKey,
        streakGap: Int = 0,
        fullAt: Double = TaskRules.defaultFullAt,
        heatMax: Int? = nil,
        isArchived: Bool = false
    ) {
        self.kind = kind
        self.period = period
        self.goalMode = goalMode
        self.target = target
        self.createdDay = createdDay
        self.streakGap = streakGap
        self.fullAt = fullAt
        self.heatMax = heatMax
        self.isArchived = isArchived
    }

    static let defaultFullAt = 0.85
    /// A task has at most this many preferred slots (DESIGN.md 5.3).
    static let maxSlots = 4

    /// False for no-limit tasks, which have no score and are left out of
    /// every average (DESIGN.md 6.3).
    var isScored: Bool { goalMode != .noLimit }

    /// N for a Do task with a target, never below 1.
    var doTarget: Int { max(target, 1) }

    /// N for an Avoid task with a limit, never below 0.
    var avoidLimit: Int { max(target, 0) }

    /// How many preferred slots this task may have: `target`, capped at 4.
    /// Avoid tasks, no-limit tasks and targets above 4 have none.
    var allowedSlotCount: Int {
        guard kind == .do, goalMode != .noLimit, target >= 1, target <= TaskRules.maxSlots else {
            return 0
        }
        return target
    }
}

/// A preferred time or day for one repetition (DESIGN.md 5.3), as a value.
nonisolated struct SlotRule: Hashable, Sendable {
    /// 0-based position.
    var index: Int
    /// Daily tasks: minutes after midnight.
    var minutes: Int?
    /// Weekly tasks: 1 (Sunday) to 7.
    var weekday: Int?
    /// Monthly tasks: 1 to 31, clamped to the month's length when used.
    var dayOfMonth: Int?

    init(index: Int, minutes: Int? = nil, weekday: Int? = nil, dayOfMonth: Int? = nil) {
        self.index = index
        self.minutes = minutes
        self.weekday = weekday
        self.dayOfMonth = dayOfMonth
    }

    /// Whether this slot falls on `day` for a task with the given period.
    /// Daily slots match every day.
    func matches(_ day: DayKey, period: TaskPeriod) -> Bool {
        switch period {
        case .daily:
            return minutes != nil
        case .weekly:
            return weekday == day.weekday
        case .monthly:
            guard let dayOfMonth else { return false }
            let length = DayKey.daysInMonth(year: day.year, month: day.month)
            return min(max(dayOfMonth, 1), length) == day.day
        }
    }
}

/// A task's rules together with everything it has logged.
nonisolated struct TaskHistory: Sendable {
    var id: UUID
    var name: String
    var rules: TaskRules
    var counts: DayCounts

    init(id: UUID = UUID(), name: String = "", rules: TaskRules, counts: DayCounts = [:]) {
        self.id = id
        self.name = name
        self.rules = rules
        self.counts = counts
    }
}
