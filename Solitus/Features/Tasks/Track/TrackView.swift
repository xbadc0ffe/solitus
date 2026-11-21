import SwiftData
import SwiftUI

/// The main screen (DESIGN.md 7.2). It answers one question: what is done,
/// and what is left?
struct TrackView: View {
    @Environment(\.slTheme) private var theme
    @Environment(\.appNow) private var now
    @Environment(\.appClock) private var clock

    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }, sort: \TaskItem.sortOrder)
    private var tasks: [TaskItem]
    @Query private var settingsQuery: [AppSettings]

    @State private var path: [TaskItem] = []

    private struct Item: Identifiable {
        let task: TaskItem
        let rules: TaskRules
        let snapshot: TaskSnapshot
        var id: UUID { task.id }
    }

    var body: some View {
        let metrics = theme.metrics
        let settings = settingsQuery.first
        let items = orderedItems(settings: settings)

        NavigationStack(path: $path) {
            SLScreen(maxWidth: nil) {
                header
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: metrics.cardMinWidth), spacing: metrics.gridColumnGap)],
                    spacing: metrics.gridRowGap
                ) {
                    ForEach(items) { item in
                        TaskCard(
                            task: item.task,
                            rules: item.rules,
                            snapshot: item.snapshot,
                            settings: TrackSettings(settings),
                            onOpen: { path.append(item.task) }
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: items.map(\.id))
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
        }
    }

    /// The date at top left and the live time at top right. No title.
    private var header: some View {
        TimelineView(.everyMinute) { timeline in
            HStack {
                Text(timeline.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                Spacer()
                Text(timeline.date.formatted(date: .omitted, time: .shortened))
            }
            .font(theme.font(.header))
            .foregroundStyle(theme.palette.textPrimary)
            .frame(height: theme.metrics.headerHeight)
            .padding(.horizontal, 4)
        }
    }

    /// The cards in Track order (DESIGN.md 6.9).
    private func orderedItems(settings: AppSettings?) -> [Item] {
        let calc = TaskCalc(weekStart: settings?.weekStart ?? 1)
        let ranker = PriorityRanker(scores: calc.scores, streakPriorityBoost: settings?.streakPriorityBoost ?? true)
        let calendar = clock.calendar

        var byID: [UUID: Item] = [:]
        var inputs: [RankInput] = []
        for task in tasks {
            let history = task.history(calendar: calendar)
            let snapshot = calc.snapshot(history, today: now.today)
            byID[task.id] = Item(task: task, rules: history.rules, snapshot: snapshot)
            inputs.append(RankInput(
                id: task.id,
                rules: history.rules,
                slots: task.slotRules,
                pinWhenLogged: task.pinWhenLogged,
                sortOrder: task.sortOrder,
                periodCount: snapshot.periodCount,
                currentStreak: snapshot.streak.current
            ))
        }
        return ranker
            .rank(inputs, today: now.today, minutesNow: now.minutes)
            .compactMap { byID[$0.id] }
    }
}
