import Foundation

/// The Add/Edit form's working copy of a task (DESIGN.md 7.4), as a plain
/// value. The form edits a draft; nothing touches the stored task until
/// Save. The rules about which controls apply live here so they can be
/// tested without a view.
nonisolated struct TaskDraft: Hashable, Sendable {
    var name = ""
    var symbol = TaskDraft.defaultSymbol
    private(set) var kind: TaskKind = .do
    private(set) var period: TaskPeriod = .daily
    private(set) var goalMode: GoalMode = .exactly
    private(set) var target = 1
    /// One place per repetition, nil where no time or day is chosen.
    private(set) var slots: [SlotRule?] = [nil]
    var remindersEnabled = false
    var pinWhenLogged = true
    var streakGap = 0
    /// "Average is full at", 50 to 100 in steps of 5.
    var fullAtPercent = 85

    static let defaultSymbol = "circle"
    static let maxTarget = 99
    static let streakGapRange = 0...14
    static let fullAtRange = 50...100
    static let fullAtStep = 5

    init() {}

    // MARK: Changes that reset other fields

    /// Switching Type resets the goal: Avoid becomes "At most 0"; Do becomes
    /// "Exactly 1".
    mutating func setKind(_ newKind: TaskKind) {
        guard newKind != kind else { return }
        kind = newKind
        switch newKind {
        case .avoid:
            goalMode = .atMost
            target = 0
        case .do:
            goalMode = .exactly
            target = 1
        }
        normalise()
    }

    /// Changing how often a task repeats clears the preferred times or
    /// days, which mean something different in each period.
    mutating func setPeriod(_ newPeriod: TaskPeriod) {
        guard newPeriod != period else { return }
        period = newPeriod
        slots = []
        normalise()
    }

    mutating func setGoalMode(_ mode: GoalMode) {
        guard GoalMode.options(for: kind).contains(mode) else { return }
        goalMode = mode
        normalise()
    }

    mutating func setTarget(_ value: Int) {
        target = value
        normalise()
    }

    /// Sets or clears one repetition's preferred time or day.
    mutating func setSlot(_ slot: SlotRule?, at index: Int) {
        guard slots.indices.contains(index) else { return }
        var placed = slot
        placed?.index = index
        slots[index] = placed
    }

    // MARK: Derived

    var targetRange: ClosedRange<Int> {
        kind == .do ? 1...TaskDraft.maxTarget : 0...TaskDraft.maxTarget
    }

    /// The stepper is hidden for No limit.
    var showsTarget: Bool { goalMode != .noLimit }

    /// Preferred times or days are hidden for Avoid tasks, for No limit and
    /// for targets above 4.
    var allowedSlotCount: Int {
        guard kind == .do, goalMode != .noLimit, target >= 1, target <= TaskRules.maxSlots else { return 0 }
        return target
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { !trimmedName.isEmpty }

    /// The chosen slots, ready to store.
    var slotRules: [SlotRule] {
        slots.compactMap { $0 }
    }

    var fullAt: Double { Double(fullAtPercent) / 100 }

    /// Keeps every field inside what the current kind and goal allow.
    private mutating func normalise() {
        if !GoalMode.options(for: kind).contains(goalMode) {
            goalMode = kind == .do ? .exactly : .atMost
        }
        target = min(max(target, targetRange.lowerBound), targetRange.upperBound)

        let count = allowedSlotCount
        if slots.count > count {
            slots.removeLast(slots.count - count)
        }
        while slots.count < count {
            slots.append(nil)
        }
        if slotRules.isEmpty {
            // Nothing to remind about without a preferred time or day.
            remindersEnabled = remindersEnabled && count > 0
        }
        if count == 0 {
            remindersEnabled = false
        }
    }

    // MARK: Loading

    /// A draft holding a stored task's values.
    init(
        name: String,
        symbol: String,
        rules: TaskRules,
        slots stored: [SlotRule],
        remindersEnabled: Bool,
        pinWhenLogged: Bool
    ) {
        self.name = name
        self.symbol = symbol
        self.kind = rules.kind
        self.period = rules.period
        self.goalMode = rules.goalMode
        self.target = rules.target
        self.remindersEnabled = remindersEnabled
        self.pinWhenLogged = pinWhenLogged
        self.streakGap = min(max(rules.streakGap, TaskDraft.streakGapRange.lowerBound), TaskDraft.streakGapRange.upperBound)
        let percent = Int((rules.fullAt * 100 / Double(TaskDraft.fullAtStep)).rounded()) * TaskDraft.fullAtStep
        self.fullAtPercent = min(max(percent, TaskDraft.fullAtRange.lowerBound), TaskDraft.fullAtRange.upperBound)
        self.slots = []
        normalise()
        for slot in stored where self.slots.indices.contains(slot.index) {
            self.slots[slot.index] = slot
        }
        self.remindersEnabled = remindersEnabled && allowedSlotCount > 0
    }

    // MARK: Words

    /// The value a chip starts with when first tapped.
    static func defaultSlot(index: Int, period: TaskPeriod) -> SlotRule {
        switch period {
        case .daily:
            let times = [8 * 60, 13 * 60, 18 * 60, 21 * 60]
            return SlotRule(index: index, minutes: times[min(max(index, 0), times.count - 1)])
        case .weekly:
            // Monday, Wednesday, Friday, Sunday.
            let days = [2, 4, 6, 1]
            return SlotRule(index: index, weekday: days[min(max(index, 0), days.count - 1)])
        case .monthly:
            let days = [1, 8, 15, 22]
            return SlotRule(index: index, dayOfMonth: days[min(max(index, 0), days.count - 1)])
        }
    }

    /// "Times per day", "Allowed per week" and so on.
    var targetLabel: String {
        let unit = CardStatusFormatter.periodUnit(period, count: 1)
        return kind == .do ? "Times per \(unit)" : "Allowed per \(unit)"
    }

    /// "None", "1 day", "2 weeks".
    static func gapLabel(_ gap: Int, period: TaskPeriod) -> String {
        gap <= 0 ? "None" : "\(gap) \(CardStatusFormatter.periodUnit(period, count: gap))"
    }

    var kindExplanation: String {
        switch kind {
        case .do: return "Something you want to do. Hold its card to mark it done."
        case .avoid: return "Something you want to avoid. Hold its card each time it happens."
        }
    }
}
