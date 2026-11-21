import Foundation
import SwiftData

extension TaskDraft {
    /// A draft of an existing task.
    init(task: TaskItem, calendar: Calendar) {
        self.init(
            name: task.name,
            symbol: task.symbol,
            rules: task.rules(calendar: calendar),
            slots: task.slotRules,
            remindersEnabled: task.remindersEnabled,
            pinWhenLogged: task.pinWhenLogged
        )
    }

    /// Writes the draft into a task and replaces its slots.
    func apply(to task: TaskItem, context: ModelContext) {
        task.name = trimmedName
        task.symbol = symbol
        task.kind = kind
        task.period = period
        task.goalMode = goalMode
        task.target = target
        task.remindersEnabled = remindersEnabled
        task.pinWhenLogged = pinWhenLogged
        task.streakGap = streakGap
        task.fullAt = fullAt

        for slot in task.slots {
            context.delete(slot)
        }
        task.slots.removeAll()
        for rule in slotRules {
            let slot = Slot(index: rule.index, minutes: rule.minutes, weekday: rule.weekday, dayOfMonth: rule.dayOfMonth)
            context.insert(slot)
            task.slots.append(slot)
        }
    }

    /// Creates and inserts a new task from the draft, placed after every
    /// existing task.
    @discardableResult
    func insert(into context: ModelContext, now: Date) -> TaskItem {
        let last = (try? context.fetch(FetchDescriptor<TaskItem>()))?.map(\.sortOrder).max() ?? -1
        let task = TaskItem(name: trimmedName, sortOrder: last + 1, createdAt: now)
        context.insert(task)
        apply(to: task, context: context)
        return task
    }
}
