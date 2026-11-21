import Foundation
import SwiftData
import UserNotifications

/// The system's answer about notifications, reduced to what the app shows.
nonisolated enum NotificationPermission: Sendable {
    case notAsked, allowed, denied

    /// Reads the current permission without asking for it.
    static func current() async -> NotificationPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notAsked
        case .denied: return .denied
        default: return .allowed
        }
    }
}

/// Rebuilds the pending reminders from the stored tasks (DESIGN.md
/// section 10). Called whenever a task is saved, an entry changes, or the
/// app comes forward.
enum ReminderCoordinator {
    static func reschedule(context: ModelContext, clock: any AppClock, weekStart: Int) {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let calendar = clock.calendar
        let inputs = tasks
            .filter { $0.remindersEnabled && !$0.isArchived }
            .map { task in
                ReminderInput(
                    id: task.id,
                    name: task.name,
                    rules: task.rules(calendar: calendar),
                    slots: task.slotRules,
                    remindersEnabled: task.remindersEnabled,
                    counts: task.dayCounts
                )
            }
        let planner = ReminderPlanner(periods: PeriodCalculator(weekStart: weekStart))
        let plan = planner.plan(inputs, today: clock.today, minutesNow: clock.minutesAfterMidnight)
        ReminderScheduler().apply(plan)
    }
}
