import SwiftData
import SwiftUI

/// Trends: a scrolling page about all tasks together (DESIGN.md 7.5).
struct TrendsView: View {
    @Environment(\.slTheme) private var theme
    @Environment(\.appNow) private var now
    @Environment(\.appClock) private var clock
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }, sort: \TaskItem.sortOrder)
    private var tasks: [TaskItem]
    @Query private var settingsQuery: [AppSettings]

    @State private var window = RunningAverage.shortWindow
    @State private var path: [TaskItem] = []

    var body: some View {
        let settings = settingsQuery.first
        let calc = TaskCalc(weekStart: settings?.weekStart ?? 1)
        let histories = tasks.map { $0.history(calendar: clock.calendar) }
        let eligible = calc.trends.eligible(histories)

        NavigationStack(path: $path) {
            SLScreen {
                SLScreenTitle("Trends")
                if eligible.isEmpty {
                    SLEmptyState(
                        symbol: "chart.line.uptrend.xyaxis",
                        title: "Nothing to chart yet",
                        message: tasks.isEmpty
                            ? "Trends appear once you have tasks and have logged a few days."
                            : "Trends follow tasks with a goal. Tasks with no limit are left out."
                    )
                } else {
                    content(histories: histories, calc: calc, settings: settings)
                }
            }
            .navigationTitle("Trends")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
        }
    }

    @ViewBuilder
    private func content(histories: [TaskHistory], calc: TaskCalc, settings: AppSettings?) -> some View {
        let today = now.today
        let groupSize = settings?.trendGroupSize ?? 5

        HeatCalendar(
            heat: calc.heat.allTasksHeat(histories, today: today),
            today: today,
            weekStart: settings?.weekStart ?? 1,
            initialMode: DebugLaunch.heatYearView ? .year : .month
        )

        graphPanel(histories: histories, calc: calc, groupSize: groupSize)

        averageCard("All tasks, last 30 days", calc.trends.totalAverage(histories, window: RunningAverage.shortWindow, endingOn: today, today: today))
        averageCard("All tasks, last 90 days", calc.trends.totalAverage(histories, window: RunningAverage.longWindow, endingOn: today, today: today))

        // The lists show the same groups as the graph's lines, by their
        // 30-day averages.
        let groups = calc.trends.groups(histories, window: RunningAverage.shortWindow, today: today, groupSize: groupSize)
        taskRows("Most completed", ids: groups.best, histories: histories, calc: calc)
        taskRows("Most neglected", ids: groups.worst, histories: histories, calc: calc)

        if settings?.streakEmphasis ?? true {
            topStreaks(histories: histories, calc: calc)
        }
    }

    // MARK: Graph

    private func graphPanel(histories: [TaskHistory], calc: TaskCalc, groupSize: Int) -> some View {
        let lines = TrendData(calc: calc, today: now.today).defaultLines(histories, window: window, groupSize: groupSize)
        return VStack(alignment: .leading, spacing: 12) {
            SLSegmented(
                options: [(RunningAverage.shortWindow, "30 days"), (RunningAverage.longWindow, "90 days")],
                selection: $window
            )
            TrendLegend(lines: lines)
            TrendGraph(lines: lines, window: window, today: now.today, calendar: clock.calendar)
                .onTapGesture {
                    router.sheet = .trendGraph
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the graph with more lines")
        }
        .padding(theme.metrics.innerPadding)
        .background(SLSurface(role: .panel))
    }

    // MARK: Cards and lists

    private func averageCard(_ label: String, _ average: Double?) -> some View {
        SLFillCard(
            label: label,
            value: CardStatusFormatter.percent(average),
            level: average,
            heat: RunningAverage.fillLevel(average: average ?? 0, fullAt: TaskRules.defaultFullAt)
        )
    }

    @ViewBuilder
    private func taskRows(_ title: String, ids: [UUID], histories: [TaskHistory], calc: TaskCalc) -> some View {
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let historyByID = Dictionary(histories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(theme.font(.secondary))
                    .foregroundStyle(theme.palette.textSecondary)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(ids, id: \.self) { id in
                    if let task = byID[id], let history = historyByID[id] {
                        let average = calc.averages.average(
                            for: history,
                            window: RunningAverage.shortWindow,
                            endingOn: now.today,
                            today: now.today
                        )
                        NavigationLink(value: task) {
                            SLFillCard(
                                label: task.name,
                                value: CardStatusFormatter.percent(average),
                                level: average,
                                heat: RunningAverage.fillLevel(average: average ?? 0, fullAt: history.rules.fullAt),
                                compact: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the task's details")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topStreaks(histories: [TaskHistory], calc: TaskCalc) -> some View {
        let streaks = calc.trends.topStreaks(histories, today: now.today)
        if !streaks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top streaks")
                    .font(theme.font(.secondary))
                    .foregroundStyle(theme.palette.textSecondary)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 12) {
                    ForEach(streaks, id: \.id) { streak in
                        SLStatCard(value: String(streak.current), label: streak.name)
                    }
                }
            }
        }
    }
}
