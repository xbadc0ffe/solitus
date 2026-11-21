import CoreTransferable
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Settings (DESIGN.md 7.8).
struct SettingsView: View {
    @Query private var settingsQuery: [AppSettings]

    var body: some View {
        SLScreen {
            SLScreenTitle("Settings")
            if let settings = settingsQuery.first {
                SettingsContent(settings: settings)
            }
        }
    }
}

/// The export, handed to the system share sheet as a `.csv` file.
nonisolated struct CSVFile: Transferable, Sendable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            Data(file.text.utf8)
        }
        .suggestedFileName("Solitus.csv")
    }
}

private struct SettingsContent: View {
    @Bindable var settings: AppSettings

    @Environment(\.slTheme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.appClock) private var clock
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router

    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]

    @State private var permission: NotificationPermission = .notAsked

    /// The glass tints offered. The first is the default.
    private static let tints: [(hex: String, name: String)] = [
        (SLPalette.defaultTintHex, "Cool"),
        ("#EDEDED", "Neutral"),
        ("#F5E6D6", "Warm"),
        ("#DCF5E4", "Green"),
        ("#E8DCF5", "Violet"),
    ]
    private static let groupSizeRange = 1...10
    private static let repository = URL(string: "https://github.com/xbadc0ffe/solitus")

    var body: some View {
        Group {
            appearance
            tracking
            streaks
            trends
            notifications
            data
            about
            if tasks.isEmpty {
                testing
            }
        }
        .onChange(of: settings.weekStart) { saveAndReschedule() }
        .onChange(of: settings.effectsEnabled) { save() }
        .onChange(of: settings.glassTintHex) { save() }
        .onChange(of: settings.streakEmphasis) { save() }
        .onChange(of: settings.streakPriorityBoost) { save() }
        .onChange(of: settings.trendGroupSize) { save() }
        .task(id: scenePhase) {
            permission = await NotificationPermission.current()
        }
    }

    // MARK: Groups

    private var appearance: some View {
        SLGroup("Appearance") {
            SLSegmented(
                options: SLSurfaceStyle.allCases.map { ($0, SettingsContent.title(for: $0)) },
                selection: $settings.surfaceStyle
            )
            SLNote("The 3D glass style comes in a later version.")
            SLToggle(
                label: "Motion and effects",
                note: "Turns off the fill animation and, later, the glass motion.",
                isOn: $settings.effectsEnabled
            )
            // OPEN: 12.5 the appearance choice (system, dark, light) appears
            // here once a light theme exists.
            VStack(alignment: .leading, spacing: 4) {
                Text("Glass tint")
                    .font(theme.font(.body))
                    .foregroundStyle(theme.palette.textPrimary)
                HStack(spacing: 4) {
                    ForEach(SettingsContent.tints, id: \.hex) { tint in
                        SLSwatch(hex: tint.hex, isSelected: settings.glassTintHex.uppercased() == tint.hex) {
                            settings.glassTintHex = tint.hex
                        }
                        .accessibilityLabel(tint.name)
                    }
                }
            }
        }
    }

    private var tracking: some View {
        SLGroup("Tracking") {
            Text("Week starts on")
                .font(theme.font(.body))
                .foregroundStyle(theme.palette.textPrimary)
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { weekday in
                    SLChip(title: HeatCalendar.weekdayInitial(weekday), isSelected: settings.weekStart == weekday) {
                        settings.weekStart = weekday
                    }
                    .accessibilityLabel(HeatCalendar.weekdayName(weekday))
                }
            }
            SLNote("Changing this regroups the history of weekly tasks.")
        }
    }

    private var streaks: some View {
        SLGroup("Streaks") {
            SLToggle(label: "Emphasise streaks", isOn: $settings.streakEmphasis)
            SLToggle(label: "Let streaks raise priority on Track", isOn: $settings.streakPriorityBoost)
        }
    }

    private var trends: some View {
        SLGroup("Trends") {
            SLStepper(
                label: "Tasks in the best and worst groups",
                value: $settings.trendGroupSize,
                range: SettingsContent.groupSizeRange
            )
        }
    }

    private var notifications: some View {
        SLGroup("Notifications") {
            switch permission {
            case .allowed:
                SLNote("Reminders are allowed. Turn them on for a task with Remind me on its edit page.")
            case .notAsked:
                SLNote("Solitus asks for permission the first time you turn on Remind me for a task.")
            case .denied:
                SLNote("Notifications are turned off for Solitus, so reminders cannot arrive.")
                SLButton(title: "Open Settings", symbol: "arrow.up.right") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var data: some View {
        SLGroup("Data") {
            let histories = tasks.map { $0.history(calendar: clock.calendar) }
            ShareLink(
                item: CSVFile(text: CSVExporter.csv(for: histories)),
                preview: SharePreview("Solitus export")
            ) {
                SLButtonLabel(title: "Export CSV", symbol: "square.and.arrow.up", fillsWidth: true)
            }
            .buttonStyle(.plain)
            SLNote("One row for each day something was logged, for every task.")
        }
    }

    private var about: some View {
        SLGroup("About") {
            HStack {
                Text("Version")
                    .foregroundStyle(theme.palette.textPrimary)
                Spacer()
                Text(SettingsContent.versionText)
                    .foregroundStyle(theme.palette.textSecondary)
            }
            .font(theme.font(.body))
            .accessibilityElement(children: .combine)
            if let repository = SettingsContent.repository {
                Link(destination: repository) {
                    SLButtonLabel(title: "Source on GitHub", symbol: "arrow.up.right", fillsWidth: true)
                }
                .buttonStyle(.plain)
            }
            SLNote("Solitus is free and open source under the MIT licence. Everything stays on this device.")
        }
    }

    /// Temporary, for trying TestFlight builds with history. Remove before
    /// the public release.
    private var testing: some View {
        SLGroup("Testing") {
            SLButton(title: "Load sample tasks", symbol: "tray", fillsWidth: true) {
                SampleData.install(context: context, clock: clock)
                router.dataChanged()
            }
            SLNote("Adds ten example tasks with four months of invented history. Shown only while there are no tasks.")
        }
    }

    // MARK: Helpers

    private func save() {
        try? context.save()
    }

    private func saveAndReschedule() {
        save()
        router.dataChanged()
    }

    private static func title(for style: SLSurfaceStyle) -> String {
        switch style {
        case .flat: return "Flat"
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
