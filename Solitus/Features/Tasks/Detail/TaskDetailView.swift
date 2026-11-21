import SwiftData
import SwiftUI

/// Task details (DESIGN.md 7.3), pushed from a card.
struct TaskDetailView: View {
    let task: TaskItem

    @Environment(\.slTheme) private var theme
    @Environment(\.appNow) private var now
    @Environment(\.appClock) private var clock
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @Query private var settingsQuery: [AppSettings]

    /// False once the task has been deleted from the edit sheet.
    private var exists: Bool {
        !task.isDeleted && task.modelContext != nil
    }

    var body: some View {
        Group {
            if exists {
                content
            } else {
                SLScreen { EmptyView() }
                    .onAppear { dismiss() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    router.sheet = .editTask(task)
                }
                .disabled(!exists)
            }
        }
    }

    private var content: some View {
        let settings = settingsQuery.first
        let weekStart = settings?.weekStart ?? 1
        let emphasis = settings?.streakEmphasis ?? true
        let calc = TaskCalc(weekStart: weekStart)
        let history = task.history(calendar: clock.calendar)
        let snapshot = calc.snapshot(history, today: now.today)

        return SLScreen {
            TaskCard(
                task: task,
                rules: history.rules,
                snapshot: snapshot,
                style: .tracker,
                settings: TrackSettings(settings)
            )

            if snapshot.todayCount > 0 {
                // OPEN: 12.4 undo lives here and only affects today.
                SLButton(title: "Undo last", symbol: "arrow.uturn.backward") {
                    undo(weekStart: weekStart)
                }
            }

            averages(history: history, snapshot: snapshot, calc: calc)

            if emphasis {
                streaks(history: history, snapshot: snapshot)
            }

            HeatCalendar(
                heat: calc.heat.heat(for: history, today: now.today),
                today: now.today,
                weekStart: weekStart,
                initialMode: DebugLaunch.heatYearView ? .year : .month
            )

            if !emphasis {
                // With streaks de-emphasised the row moves to the bottom.
                streaks(history: history, snapshot: snapshot)
            }
        }
    }

    /// "Last 30 days" and "Last 90 days": the running averages for scored
    /// tasks, totals for no-limit tasks.
    @ViewBuilder
    private func averages(history: TaskHistory, snapshot: TaskSnapshot, calc: TaskCalc) -> some View {
        let rules = history.rules
        if rules.isScored {
            averageCard("Last 30 days", snapshot.average30, fullAt: rules.fullAt)
            averageCard("Last 90 days", snapshot.average90, fullAt: rules.fullAt)
        } else {
            SLFillCard(
                label: "Last 30 days",
                value: String(calc.total(history, days: RunningAverage.shortWindow, today: now.today)),
                level: nil,
                heat: 0
            )
            SLFillCard(
                label: "Last 90 days",
                value: String(calc.total(history, days: RunningAverage.longWindow, today: now.today)),
                level: nil,
                heat: 0
            )
        }
    }

    private func averageCard(_ label: String, _ average: Double?, fullAt: Double) -> some View {
        SLFillCard(
            label: label,
            value: CardStatusFormatter.percent(average),
            level: average,
            heat: RunningAverage.fillLevel(average: average ?? 0, fullAt: fullAt)
        )
    }

    /// Current, Average and Best. Numbers only.
    private func streaks(history: TaskHistory, snapshot: TaskSnapshot) -> some View {
        let hasStreak = history.rules.isScored || history.rules.kind == .do
        let streak = snapshot.streak
        return HStack(spacing: 12) {
            SLStatCard(value: hasStreak ? String(streak.current) : CardStatusFormatter.dash, label: "Current")
            SLStatCard(
                value: hasStreak ? streak.average.formatted(.number.precision(.fractionLength(0...1))) : CardStatusFormatter.dash,
                label: "Average"
            )
            SLStatCard(value: hasStreak ? String(streak.best) : CardStatusFormatter.dash, label: "Best")
        }
    }

    private func undo(weekStart: Int) {
        let store = EntryStore(context: context, clock: clock, weekStart: weekStart)
        if (try? store.undoOne(for: task)) == true {
            router.dataChanged()
        }
    }
}
