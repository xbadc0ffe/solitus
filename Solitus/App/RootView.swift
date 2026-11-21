import SwiftData
import SwiftUI

/// The app shell: the background, the current section's screen, and the
/// floating tab bar (DESIGN.md 4.4 and 7.1).
///
/// The tab bar is built from a list of `AppSection` values. This view also
/// owns the design environment (theme, surface style, motion tilt) and sets
/// it once for everything below.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var settingsQuery: [AppSettings]

    @State private var selection: AppSection = DebugLaunch.startTab ?? .track
    @State private var motion = SLMotionProvider(source: .still)
    @State private var router = AppRouter()
    @State private var now = AppNow(clock: SystemClock())

    private let clock: any AppClock = SystemClock()

    private let sections = AppSection.tasksSections

    private var settings: AppSettings? { settingsQuery.first }

    private var theme: SLTheme {
        SLTheme.darkTinted(
            hex: settings?.glassTintHex ?? SLPalette.defaultTintHex,
            dynamicTypeSize: dynamicTypeSize,
            increasedContrast: contrast == .increased
        )
    }

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            SLBackground()

            screen(for: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            SLTabBar(sections: sections, selection: $selection)
        }
        .slSheet(item: $router.sheet) { route in
            switch route {
            case .addTask:
                TaskEditSheet(task: nil, calendar: clock.calendar)
            case .editTask(let task):
                TaskEditSheet(task: task, calendar: clock.calendar)
            case .trendGraph:
                TrendSheet()
            }
        }
        .slDesign(
            theme: theme,
            surfaceStyle: settings?.surfaceStyle ?? .flat,
            tilt: motion.tilt
        )
        .environment(router)
        .environment(\.appClock, clock)
        .environment(\.appNow, now)
        // "Now" moves on every minute, on the system's day change, and when
        // the app comes forward (DESIGN.md 8.4).
        .background {
            TimelineView(.everyMinute) { timeline in
                Color.clear.onChange(of: timeline.date, initial: true) { refreshNow() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshNow()
        }
        // OPEN: 12.5 there is no light theme yet, so the app is always dark.
        .preferredColorScheme(.dark)
        .task {
            AppSettings.ensureExists(in: context)
            SampleData.installIfRequested(context: context)
            rescheduleReminders()
            switch DebugLaunch.openSheet {
            case "add": router.sheet = .addTask
            case "edit":
                var first = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)])
                first.fetchLimit = 1
                if let task = try? context.fetch(first).first {
                    router.sheet = .editTask(task)
                }
            case "trend": router.sheet = .trendGraph
            default: break
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshNow()
                rescheduleReminders()
            }
            updateMotion()
        }
        // Reminders are rebuilt whenever a task is saved or an entry changes
        // (DESIGN.md section 10).
        .onChange(of: router.changeCount) { rescheduleReminders() }
        .onChange(of: reduceMotion) { updateMotion() }
        .onChange(of: settings?.effectsEnabled) { updateMotion() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            updateMotion()
        }
    }

    /// Motion runs only in the foreground, and never with Reduce Motion,
    /// Low Power Mode or the app's own effects switch off (DESIGN.md 9.5).
    private func updateMotion() {
        let allowed = scenePhase == .active
            && !reduceMotion
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && (settings?.effectsEnabled ?? true)
        if allowed {
            motion.start()
        } else {
            motion.stop()
        }
    }

    private func rescheduleReminders() {
        ReminderCoordinator.reschedule(context: context, clock: clock, weekStart: settings?.weekStart ?? 1)
    }

    private func refreshNow() {
        let fresh = AppNow(clock: clock)
        if fresh != now {
            now = fresh
        }
    }

    @ViewBuilder
    private func screen(for section: AppSection) -> some View {
        switch section {
        case .track: TrackView()
        case .trends: TrendsView()
        case .tasks: TaskListView()
        case .settings: SettingsView()
        }
    }
}
