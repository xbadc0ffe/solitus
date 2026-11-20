import Foundation
import SwiftData

/// A task or habit (DESIGN.md 5.1).
///
/// Named `TaskItem` because `Task` belongs to Swift concurrency. Enums are
/// stored as raw strings with typed accessors beside them. Every stored
/// property has an inline default so later additions migrate cleanly.
@Model
final class TaskItem {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbol name.
    var symbol: String = "circle"
    // OPEN: 12.9 per-task colours are deferred; this field is reserved.
    var colorHex: String?
    var kindRaw: String = "do"
    var periodRaw: String = "daily"
    var goalModeRaw: String = "exactly"
    /// N. Ignored for `noLimit`. Default 1 for Do, 0 for Avoid.
    var target: Int = 1
    /// Optional label such as "glasses".
    var unit: String?
    var remindersEnabled: Bool = false
    /// Avoid only: move the card to the top of Track once logged.
    var pinWhenLogged: Bool = true
    /// Periods a streak may skip.
    var streakGap: Int = 0
    /// Running average that counts as full.
    var fullAt: Double = 0.85
    /// Top of the heat scale for count-based heat; nil means automatic.
    var heatMax: Int?
    var quickStatRaw: String = "progress"
    /// Manual order, used as a tiebreak.
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    @Relationship(deleteRule: .cascade, inverse: \Slot.task)
    var slots: [Slot] = []

    @Relationship(deleteRule: .cascade, inverse: \Entry.task)
    var entries: [Entry] = []

    init(
        name: String,
        symbol: String = "circle",
        kind: TaskKind = .do,
        period: TaskPeriod = .daily,
        goalMode: GoalMode = .exactly,
        target: Int = 1,
        unit: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date
    ) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.kindRaw = kind.rawValue
        self.periodRaw = period.rawValue
        self.goalModeRaw = goalMode.rawValue
        self.target = target
        self.unit = unit
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    // MARK: Typed accessors

    var kind: TaskKind {
        get { TaskKind(rawValue: kindRaw) ?? .do }
        set { kindRaw = newValue.rawValue }
    }

    var period: TaskPeriod {
        get { TaskPeriod(rawValue: periodRaw) ?? .daily }
        set { periodRaw = newValue.rawValue }
    }

    var goalMode: GoalMode {
        get { GoalMode(rawValue: goalModeRaw) ?? .exactly }
        set { goalModeRaw = newValue.rawValue }
    }

    var quickStat: QuickStat {
        get { QuickStat(rawValue: quickStatRaw) ?? .progress }
        set { quickStatRaw = newValue.rawValue }
    }

    // MARK: Snapshots for the services

    /// The task's rules as a value. `calendar` turns `createdAt` into a day.
    func rules(calendar: Calendar) -> TaskRules {
        TaskRules(
            kind: kind,
            period: period,
            goalMode: goalMode,
            target: target,
            createdDay: DayKey(date: createdAt, calendar: calendar),
            streakGap: streakGap,
            fullAt: fullAt,
            heatMax: heatMax,
            isArchived: isArchived
        )
    }

    /// Everything logged, per day. Rows with an unreadable key are skipped.
    var dayCounts: DayCounts {
        var counts: DayCounts = [:]
        for entry in entries {
            guard let day = DayKey(string: entry.dayKey) else { continue }
            counts[day, default: 0] += entry.count
        }
        return counts
    }

    /// Rules and counts together.
    func history(calendar: Calendar) -> TaskHistory {
        TaskHistory(id: id, name: name, rules: rules(calendar: calendar), counts: dayCounts)
    }

    /// The preferred slots as values, in index order.
    var slotRules: [SlotRule] {
        slots
            .map { SlotRule(index: $0.index, minutes: $0.minutes, weekday: $0.weekday, dayOfMonth: $0.dayOfMonth) }
            .sorted { $0.index < $1.index }
    }
}
