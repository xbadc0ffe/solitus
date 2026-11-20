import Foundation
import UserNotifications

/// What the planner needs to know about one task.
nonisolated struct ReminderInput: Sendable {
    var id: UUID
    var name: String
    var rules: TaskRules
    var slots: [SlotRule]
    var remindersEnabled: Bool
    var counts: DayCounts

    init(
        id: UUID = UUID(),
        name: String,
        rules: TaskRules,
        slots: [SlotRule],
        remindersEnabled: Bool = true,
        counts: DayCounts = [:]
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.slots = slots
        self.remindersEnabled = remindersEnabled
        self.counts = counts
    }
}

/// One notification to schedule.
nonisolated struct PlannedReminder: Hashable, Sendable {
    /// Stable per task, day and slot, so rescheduling replaces rather than
    /// duplicates.
    let identifier: String
    let taskID: UUID
    let taskName: String
    let day: DayKey
    /// Minutes after local midnight.
    let minutes: Int
    let slotIndex: Int
}

/// Decides which reminders should exist (DESIGN.md section 10). Pure: it
/// reads values and returns values, so it can be tested without the
/// notification system.
///
/// - Daily task with timed slots: a notification at each slot's time, only
///   if that repetition is not yet done.
/// - Weekly and monthly tasks: a notification on the preferred day, only if
///   still needed.
///
/// A repetition is "done" when the period's count is above the slot's index.
/// Future periods are planned as if nothing is logged; the plan is rebuilt
/// whenever a task is saved, an entry changes or the app comes forward.
nonisolated struct ReminderPlanner: Sendable {
    // OPEN: 12.8 weekly and monthly reminders fire at 9:00 AM.
    static let longPeriodReminderMinutes = 9 * 60
    /// How many days ahead to plan, counting today.
    static let dailyHorizonDays = 7
    static let weeklyHorizonDays = 14
    static let monthlyHorizonDays = 35
    /// iOS keeps at most 64 pending local notifications per app.
    static let maxPending = 60

    let periods: PeriodCalculator

    init(periods: PeriodCalculator = PeriodCalculator()) {
        self.periods = periods
    }

    /// Every reminder that should be pending, soonest first, capped at
    /// `maxPending`.
    func plan(_ inputs: [ReminderInput], today: DayKey, minutesNow: Int) -> [PlannedReminder] {
        var all: [PlannedReminder] = []
        for input in inputs {
            all.append(contentsOf: plan(for: input, today: today, minutesNow: minutesNow))
        }
        let sorted = all.sorted { a, b in
            if a.day != b.day { return a.day < b.day }
            if a.minutes != b.minutes { return a.minutes < b.minutes }
            return a.identifier < b.identifier
        }
        return Array(sorted.prefix(ReminderPlanner.maxPending))
    }

    func plan(for input: ReminderInput, today: DayKey, minutesNow: Int) -> [PlannedReminder] {
        let rules = input.rules
        guard input.remindersEnabled, !rules.isArchived, rules.allowedSlotCount > 0 else { return [] }

        let slots = input.slots
            .filter { $0.index >= 0 && $0.index < rules.allowedSlotCount }
            .sorted { $0.index < $1.index }
        guard !slots.isEmpty else { return [] }

        let horizon: Int
        switch rules.period {
        case .daily: horizon = ReminderPlanner.dailyHorizonDays
        case .weekly: horizon = ReminderPlanner.weeklyHorizonDays
        case .monthly: horizon = ReminderPlanner.monthlyHorizonDays
        }

        let currentSpan = periods.span(containing: today, period: rules.period)
        let currentCount = periods.count(in: currentSpan, counts: input.counts)

        var planned: [PlannedReminder] = []
        for offset in 0..<horizon {
            let day = today.adding(offset)
            let doneInPeriod = currentSpan.contains(day) ? currentCount : 0
            for slot in slots where slot.matches(day, period: rules.period) {
                // Skip repetitions that are already done.
                guard slot.index >= doneInPeriod else { continue }
                let minutes: Int
                if rules.period == .daily {
                    minutes = slot.minutes ?? ReminderPlanner.longPeriodReminderMinutes
                } else {
                    minutes = ReminderPlanner.longPeriodReminderMinutes
                }
                // Skip times that have already passed today.
                if offset == 0 && minutes <= minutesNow { continue }
                planned.append(PlannedReminder(
                    identifier: "\(input.id.uuidString)|\(day.string)|\(slot.index)",
                    taskID: input.id,
                    taskName: input.name,
                    day: day,
                    minutes: minutes,
                    slotIndex: slot.index
                ))
            }
        }
        return planned
    }
}

/// Applies a plan to the system's notification centre. Local notifications
/// only; nothing here uses the network.
///
/// Permission is requested the first time a user turns on "Remind me",
/// never at launch (DESIGN.md section 10).
struct ReminderScheduler {
    /// Asks for permission to show notifications. Returns whether it was
    /// granted.
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    /// Replaces every pending reminder with the given plan.
    func apply(_ plan: [PlannedReminder]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = reminder.taskName
            content.body = "Still to do."
            content.sound = .default

            var components = DateComponents()
            components.year = reminder.day.year
            components.month = reminder.day.month
            components.day = reminder.day.day
            components.hour = reminder.minutes / 60
            components.minute = reminder.minutes % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Removes every pending reminder.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
