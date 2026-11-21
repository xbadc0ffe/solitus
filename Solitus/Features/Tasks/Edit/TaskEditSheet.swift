import SwiftData
import SwiftUI
import UIKit

/// Add or edit a task (DESIGN.md 7.4). One form for both, presented as a
/// sheet. Editing an existing task adds Archive and Delete at the bottom.
struct TaskEditSheet: View {
    /// Nil when adding a task.
    let task: TaskItem?

    @Environment(\.slTheme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.appClock) private var clock
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router

    @Query private var settingsQuery: [AppSettings]

    @State private var draft: TaskDraft
    @State private var showsSymbols = false
    /// The chip whose time or day is being chosen.
    @State private var editingSlot: Int?
    @State private var confirmsDelete = false
    @State private var permissionDenied = false

    init(task: TaskItem?, calendar: Calendar) {
        self.task = task
        _draft = State(initialValue: task.map { TaskDraft(task: $0, calendar: calendar) } ?? TaskDraft())
    }

    var body: some View {
        VStack(spacing: 0) {
            SLSheetBar(
                title: task == nil ? "New task" : "Edit task",
                leading: "Cancel",
                trailing: "Save",
                trailingEnabled: draft.canSave,
                onLeading: { router.sheet = nil },
                onTrailing: save
            )
            ScrollView {
                VStack(alignment: .leading, spacing: theme.metrics.panelSpacing) {
                    nameGroup
                    typeGroup
                    repeatsGroup
                    goalGroup
                    if draft.allowedSlotCount > 0 {
                        slotsGroup
                    }
                    if draft.kind == .avoid {
                        SLGroup("When logged") {
                            SLToggle(label: "Move to the top once logged", isOn: $draft.pinWhenLogged)
                        }
                    }
                    scoringGroup
                    if task != nil {
                        manageGroup
                    }
                }
                .padding(.horizontal, theme.metrics.screenMargin)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .confirmationDialog(
            "Delete this task and everything logged for it?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Groups

    private var nameGroup: some View {
        SLGroup("Name") {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { showsSymbols.toggle() }
                } label: {
                    Image(systemName: draft.symbol)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(theme.palette.textPrimary)
                        .frame(width: theme.metrics.minTapTarget, height: theme.metrics.minTapTarget)
                        .background(SLSurface(role: showsSymbols ? .raised : .well, cornerRadius: theme.metrics.wellRadius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Icon")
                .accessibilityHint("Shows the icons to choose from")
                SLTextField(placeholder: "Task name", text: $draft.name)
            }
            if showsSymbols {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                    ForEach(SymbolCatalog.symbols, id: \.self) { symbol in
                        Button {
                            draft.symbol = symbol
                            withAnimation(.snappy(duration: 0.2)) { showsSymbols = false }
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(theme.palette.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: theme.metrics.minTapTarget)
                                .background {
                                    if symbol == draft.symbol {
                                        SLSurface(role: .raised)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                    }
                }
            }
        }
    }

    private var typeGroup: some View {
        SLGroup("Type") {
            SLSegmented(
                options: [(TaskKind.do, "Do"), (TaskKind.avoid, "Avoid")],
                selection: Binding(get: { draft.kind }, set: { draft.setKind($0); editingSlot = nil })
            )
            SLNote(draft.kindExplanation)
        }
    }

    private var repeatsGroup: some View {
        SLGroup("Repeats") {
            SLSegmented(
                options: [(TaskPeriod.daily, "Daily"), (TaskPeriod.weekly, "Weekly"), (TaskPeriod.monthly, "Monthly")],
                selection: Binding(get: { draft.period }, set: { draft.setPeriod($0); editingSlot = nil })
            )
        }
    }

    private var goalGroup: some View {
        SLGroup("Goal") {
            SLSegmented(
                options: GoalMode.options(for: draft.kind).map { ($0, TaskEditSheet.title(for: $0)) },
                selection: Binding(get: { draft.goalMode }, set: { draft.setGoalMode($0); editingSlot = nil })
            )
            if draft.showsTarget {
                SLStepper(
                    label: draft.targetLabel,
                    value: Binding(get: { draft.target }, set: { draft.setTarget($0); editingSlot = nil }),
                    range: draft.targetRange
                )
            }
        }
    }

    private var slotsGroup: some View {
        SLGroup(draft.period == .daily ? "Preferred times" : "Preferred days") {
            HStack(spacing: 8) {
                ForEach(Array(draft.slots.enumerated()), id: \.offset) { index, slot in
                    SLChip(title: slotTitle(slot), isSelected: editingSlot == index) {
                        withAnimation(.snappy(duration: 0.2)) {
                            if editingSlot == index {
                                editingSlot = nil
                            } else {
                                if slot == nil {
                                    draft.setSlot(TaskDraft.defaultSlot(index: index, period: draft.period), at: index)
                                }
                                editingSlot = index
                            }
                        }
                    }
                }
            }
            if let index = editingSlot, draft.slots.indices.contains(index), let slot = draft.slots[index] {
                slotEditor(slot, at: index)
            }
            SLNote("These are suggestions. They set the order on Track and when a reminder arrives.")
            SLToggle(
                label: "Remind me",
                note: reminderNote,
                isOn: Binding(get: { draft.remindersEnabled }, set: setReminders)
            )
            if permissionDenied {
                SLButton(title: "Open Settings", symbol: "arrow.up.right") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var scoringGroup: some View {
        SLGroup("Scoring") {
            SLStepper(
                label: "Streak allows a gap of",
                value: $draft.streakGap,
                range: TaskDraft.streakGapRange,
                format: { TaskDraft.gapLabel($0, period: draft.period) }
            )
            if draft.goalMode != .noLimit {
                SLStepper(
                    label: "Average is full at",
                    value: $draft.fullAtPercent,
                    range: TaskDraft.fullAtRange,
                    step: TaskDraft.fullAtStep,
                    format: { "\($0)%" }
                )
            }
        }
    }

    private var manageGroup: some View {
        SLGroup("Manage") {
            SLButton(
                title: task?.isArchived == true ? "Restore from archive" : "Archive",
                symbol: "archivebox",
                fillsWidth: true,
                action: toggleArchive
            )
            SLNote("An archived task leaves Track and Trends but keeps its history.")
            SLButton(title: "Delete", symbol: "trash", tone: .destructive, fillsWidth: true) {
                confirmsDelete = true
            }
        }
    }

    // MARK: Slots

    private func slotTitle(_ slot: SlotRule?) -> String {
        guard let slot else { return "Add" }
        if let minutes = slot.minutes {
            return timeText(minutes)
        }
        if let weekday = slot.weekday {
            return HeatCalendar.shortWeekdayName(weekday)
        }
        if let dayOfMonth = slot.dayOfMonth {
            return "Day \(dayOfMonth)"
        }
        return "Add"
    }

    private func timeText(_ minutes: Int) -> String {
        guard let date = clock.today.date(in: clock.calendar, hour: minutes / 60, minute: minutes % 60) else {
            return String(format: "%d:%02d", minutes / 60, minutes % 60)
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private func slotEditor(_ slot: SlotRule, at index: Int) -> some View {
        switch draft.period {
        case .daily:
            DatePicker(
                "Time",
                selection: Binding(
                    get: {
                        let minutes = slot.minutes ?? 0
                        return clock.today.date(in: clock.calendar, hour: minutes / 60, minute: minutes % 60) ?? clock.now
                    },
                    set: { date in
                        let parts = clock.calendar.dateComponents([.hour, .minute], from: date)
                        draft.setSlot(SlotRule(index: index, minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)), at: index)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.timeZone, clock.calendar.timeZone)
            .frame(maxWidth: .infinity, maxHeight: 130)
            .clipped()
        case .weekly:
            let weekStart = settingsQuery.first?.weekStart ?? 1
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { offset in
                    let weekday = (weekStart - 1 + offset) % 7 + 1
                    SLChip(title: HeatCalendar.weekdayInitial(weekday), isSelected: slot.weekday == weekday) {
                        draft.setSlot(SlotRule(index: index, weekday: weekday), at: index)
                    }
                    .accessibilityLabel(HeatCalendar.weekdayName(weekday))
                }
            }
        case .monthly:
            SLStepper(
                label: "Day of the month",
                value: Binding(
                    get: { slot.dayOfMonth ?? 1 },
                    set: { draft.setSlot(SlotRule(index: index, dayOfMonth: $0), at: index) }
                ),
                range: 1...31
            )
        }
        SLButton(title: "Clear this one", symbol: "xmark") {
            withAnimation(.snappy(duration: 0.2)) {
                draft.setSlot(nil, at: index)
                editingSlot = nil
            }
        }
    }

    // MARK: Reminders

    private var reminderNote: String? {
        if permissionDenied {
            return "Notifications are turned off for Solitus. Turn them on in Settings to be reminded."
        }
        if draft.remindersEnabled && draft.slotRules.isEmpty {
            return draft.period == .daily ? "Choose at least one time above." : "Choose at least one day above."
        }
        return nil
    }

    /// Permission is asked for the first time the switch is turned on, never
    /// at launch (DESIGN.md section 10).
    private func setReminders(_ isOn: Bool) {
        guard isOn else {
            draft.remindersEnabled = false
            return
        }
        Task {
            let granted = await ReminderScheduler().requestAuthorization()
            settingsQuery.first?.notificationsRequested = true
            permissionDenied = !granted
            draft.remindersEnabled = granted
        }
    }

    // MARK: Actions

    private func save() {
        guard draft.canSave else { return }
        if let task {
            draft.apply(to: task, context: context)
        } else {
            draft.insert(into: context, now: clock.now)
        }
        finish()
    }

    private func toggleArchive() {
        guard let task else { return }
        task.isArchived.toggle()
        finish()
    }

    private func delete() {
        guard let task else { return }
        context.delete(task)
        finish()
    }

    private func finish() {
        try? context.save()
        router.dataChanged()
        router.sheet = nil
    }

    private static func title(for mode: GoalMode) -> String {
        switch mode {
        case .exactly: return "Exactly"
        case .atLeast: return "At least"
        case .atMost: return "At most"
        case .noLimit: return "No limit"
        }
    }
}
