import SwiftData
import SwiftUI

/// The trend sheet (DESIGN.md 7.6), opened from the Trends graph: the 30/90
/// switch, a taller version of the same scrolling graph, and a list of
/// lines with switches. Any task's own line can be added.
///
/// Changes here affect this sheet only and are remembered between openings;
/// the graph on the Trends page always shows the three default lines.
struct TrendSheet: View {
    @Environment(\.slTheme) private var theme
    @Environment(\.appNow) private var now
    @Environment(\.appClock) private var clock
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }, sort: \TaskItem.sortOrder)
    private var tasks: [TaskItem]
    @Query private var settingsQuery: [AppSettings]

    @AppStorage("trendSheetLines") private var storedState = ""
    @State private var window = RunningAverage.shortWindow
    @State private var showsPicker = false

    private var state: TrendSheetState { TrendSheetState(json: storedState) }

    private func update(_ change: (inout TrendSheetState) -> Void) {
        var next = state
        change(&next)
        storedState = next.json
    }

    var body: some View {
        let settings = settingsQuery.first
        let calc = TaskCalc(weekStart: settings?.weekStart ?? 1)
        let data = TrendData(calc: calc, today: now.today)
        let histories = tasks.map { $0.history(calendar: clock.calendar) }
        let scored = histories.filter { $0.rules.isScored }
        let state = self.state

        let defaults = data.defaultLines(histories, window: window, groupSize: settings?.trendGroupSize ?? 5)
        let first = data.firstDay(histories, window: window)
        // A task keeps its colour and dash for as long as it stays added.
        let added: [TrendLine] = state.taskIDs.enumerated().compactMap { index, id in
            scored.first { $0.id == id }.map { data.taskLine($0, index: index, window: window, first: first) }
        }
        let shown = defaults.filter { !state.hidden.contains($0.id) } + added
        let available = scored.filter { !state.taskIDs.contains($0.id) }

        VStack(spacing: 0) {
            SLSheetBar(title: "Running average", leading: "Done", trailing: nil, onLeading: { router.sheet = nil })
            ScrollView {
                VStack(alignment: .leading, spacing: theme.metrics.panelSpacing) {
                    SLSegmented(
                        options: [(RunningAverage.shortWindow, "30 days"), (RunningAverage.longWindow, "90 days")],
                        selection: $window
                    )
                    TrendGraph(lines: shown, window: window, today: now.today, calendar: clock.calendar, height: 280)
                        .padding(theme.metrics.innerPadding)
                        .background(SLSurface(role: .panel))

                    SLGroup("Lines") {
                        ForEach(defaults) { line in
                            lineRow(line, isOn: !state.hidden.contains(line.id)) { isOn in
                                update { $0.hidden = isOn ? $0.hidden.filter { $0 != line.id } : $0.hidden + [line.id] }
                            }
                        }
                        ForEach(added) { line in
                            lineRow(line, isOn: true) { _ in
                                update { $0.taskIDs.removeAll { $0.uuidString == line.id } }
                            }
                        }
                        if !available.isEmpty {
                            SLButton(title: showsPicker ? "Done adding" : "Add a task", symbol: showsPicker ? nil : "plus", fillsWidth: true) {
                                withAnimation(.snappy(duration: 0.2)) { showsPicker.toggle() }
                            }
                            if showsPicker {
                                ForEach(available, id: \.id) { history in
                                    SLChip(title: history.name) {
                                        update { $0.taskIDs.append(history.id) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, theme.metrics.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// A sample of the stroke, the name, today's value and a switch.
    private func lineRow(_ line: TrendLine, isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 10) {
            TrendLineSample(kind: line.kind)
            SLToggle(
                label: "\(line.name)  \(CardStatusFormatter.percent(line.current))",
                isOn: Binding(get: { isOn }, set: set)
            )
        }
    }
}
