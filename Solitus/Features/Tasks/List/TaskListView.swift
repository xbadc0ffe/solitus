import SwiftData
import SwiftUI

/// Tasks: the management list (DESIGN.md 7.7). Every unarchived task as a
/// row in manual order, drag to reorder, an add button, and a collapsed
/// Archived section at the bottom.
struct TaskListView: View {
    @Environment(\.slTheme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.appClock) private var clock
    @Environment(AppRouter.self) private var router

    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]

    @State private var showsArchived = false
    /// The order while a row is being dragged.
    @State private var dragOrder: [UUID]?
    @State private var draggedID: UUID?
    @State private var dragStartIndex = 0
    @State private var dragOffset: CGFloat = 0

    private static let rowSpacing: CGFloat = 10

    var body: some View {
        let active = allTasks.filter { !$0.isArchived }
        let archived = allTasks.filter { $0.isArchived }
        let ordered = orderedTasks(active)

        SLScreen {
            HStack {
                SLScreenTitle("Tasks")
                Spacer()
                SLButton(title: "Add", symbol: "plus") {
                    router.sheet = .addTask
                }
                .accessibilityLabel("Add a task")
            }

            if active.isEmpty {
                SLEmptyState(
                    symbol: "square.grid.2x2",
                    title: "No tasks yet",
                    message: "Add something you want to do, or something you want to avoid."
                )
            }

            VStack(spacing: TaskListView.rowSpacing) {
                ForEach(ordered) { task in
                    row(task, in: ordered)
                        .offset(y: task.id == draggedID ? dragOffset : 0)
                        .zIndex(task.id == draggedID ? 1 : 0)
                }
            }

            if !archived.isEmpty {
                archivedSection(archived)
            }
        }
    }

    // MARK: Rows

    private func row(_ task: TaskItem, in ordered: [TaskItem]) -> some View {
        let palette = theme.palette
        let tap = theme.metrics.minTapTarget
        return HStack(spacing: 12) {
            Button {
                router.sheet = .editTask(task)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: task.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name)
                            .font(theme.font(.body))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Text(CardStatusFormatter.summary(rules: task.rules(calendar: clock.calendar)))
                            .font(theme.font(.secondary))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: theme.metrics.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the task to edit")

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.textFaint)
                .frame(width: tap, height: tap)
                .contentShape(Rectangle())
                .highPriorityGesture(dragGesture(for: task, in: ordered))
                .accessibilityLabel("Reorder \(task.name)")
                .accessibilityAction(named: "Move up") { move(task, by: -1, in: ordered) }
                .accessibilityAction(named: "Move down") { move(task, by: 1, in: ordered) }
        }
        .padding(.leading, theme.metrics.innerPadding)
        .padding(.trailing, 4)
        .background(SLSurface(role: .row))
    }

    private func archivedSection(_ archived: [TaskItem]) -> some View {
        let palette = theme.palette
        return VStack(alignment: .leading, spacing: TaskListView.rowSpacing) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { showsArchived.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Archived (\(archived.count))")
                    Image(systemName: showsArchived ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(theme.font(.secondary))
                .foregroundStyle(palette.textSecondary)
                .frame(minHeight: theme.metrics.minTapTarget)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsArchived {
                ForEach(archived) { task in
                    HStack(spacing: 12) {
                        Image(systemName: task.symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 28)
                        Text(task.name)
                            .font(theme.font(.body))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        SLButton(title: "Restore") {
                            task.isArchived = false
                            try? context.save()
                            router.dataChanged()
                        }
                        Button {
                            router.sheet = .editTask(task)
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(palette.textSecondary)
                                .frame(width: theme.metrics.minTapTarget, height: theme.metrics.minTapTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(task.name)")
                    }
                    .padding(.leading, theme.metrics.innerPadding)
                    .padding(.trailing, 4)
                    .frame(minHeight: theme.metrics.rowHeight)
                    .background(SLSurface(role: .row))
                }
            }
        }
    }

    // MARK: Reordering

    private func orderedTasks(_ active: [TaskItem]) -> [TaskItem] {
        guard let dragOrder else { return active }
        let byID = Dictionary(active.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return dragOrder.compactMap { byID[$0] }
    }

    /// Dragging a row's handle moves it through the list; the other rows
    /// step out of its way.
    private func dragGesture(for task: TaskItem, in ordered: [TaskItem]) -> some Gesture {
        let stride = theme.metrics.rowHeight + TaskListView.rowSpacing
        return DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                if draggedID == nil {
                    draggedID = task.id
                    dragOrder = ordered.map(\.id)
                    dragStartIndex = ordered.firstIndex { $0.id == task.id } ?? 0
                }
                guard var order = dragOrder, let current = order.firstIndex(of: task.id) else { return }
                let steps = Int((value.translation.height / stride).rounded())
                let target = min(max(dragStartIndex + steps, 0), order.count - 1)
                if target != current {
                    order.remove(at: current)
                    order.insert(task.id, at: target)
                    withAnimation(.snappy(duration: 0.2)) {
                        dragOrder = order
                    }
                }
                dragOffset = value.translation.height - CGFloat(target - dragStartIndex) * stride
            }
            .onEnded { _ in
                if let order = dragOrder {
                    store(order: order, among: ordered)
                }
                withAnimation(.snappy(duration: 0.2)) {
                    dragOffset = 0
                    draggedID = nil
                    dragOrder = nil
                }
            }
    }

    private func move(_ task: TaskItem, by steps: Int, in ordered: [TaskItem]) {
        var order = ordered.map(\.id)
        guard let current = order.firstIndex(of: task.id) else { return }
        let target = min(max(current + steps, 0), order.count - 1)
        guard target != current else { return }
        order.remove(at: current)
        order.insert(task.id, at: target)
        store(order: order, among: ordered)
    }

    private func store(order: [UUID], among tasks: [TaskItem]) {
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (index, id) in order.enumerated() {
            byID[id]?.sortOrder = index
        }
        try? context.save()
        router.dataChanged()
    }
}
