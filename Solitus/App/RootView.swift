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
    @Query private var settingsQuery: [AppSettings]

    @State private var selection: AppSection = .track
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
        ZStack(alignment: .bottom) {
            SLBackground()

            screen(for: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            SLTabBar(sections: sections, selection: $selection)
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
            #if DEBUG
            SampleData.installIfRequested(context: context)
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshNow()
                motion.start()
            } else {
                motion.stop()
            }
        }
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
