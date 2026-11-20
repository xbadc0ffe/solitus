import Foundation

/// A top-level area of the app, shown as one tab (DESIGN.md 4.4).
///
/// Today every section belongs to Tasks. Schedule and Finances will add
/// their own, and the navigation will be redesigned then, so nothing should
/// assume there are exactly four sections.
enum AppSection: String, CaseIterable, Identifiable {
    case track, trends, tasks, settings

    var id: String { rawValue }

    /// The sections of the Tasks feature area, in tab order.
    static let tasksSections: [AppSection] = [.track, .trends, .tasks, .settings]

    var title: String {
        switch self {
        case .track: return "Track"
        case .trends: return "Trends"
        case .tasks: return "Tasks"
        case .settings: return "Settings"
        }
    }

    /// SF Symbol name for the tab.
    var symbol: String {
        switch self {
        case .track: return "checkmark.circle"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .tasks: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}
