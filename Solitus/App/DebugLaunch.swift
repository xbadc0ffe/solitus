import Foundation

/// Launch arguments that put the app in a given state, so a screen can be
/// checked from the command line on a machine with no way to tap. They do
/// nothing in release builds.
///
///     -startTab trends          open on a tab (track, trends, tasks, settings)
///     -openFirstTask            push the first Track card's details
///     -heatYearView             heat calendars start in the year view
///     -openSheet add            present a sheet (add, edit, trend)
///     -inMemoryStore            start with an empty store that is not kept (UI tests)
enum DebugLaunch {
    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static let startTab: AppSection? = value(after: "-startTab").flatMap { AppSection(rawValue: $0) }
    static let openFirstTask = arguments.contains("-openFirstTask")
    static let heatYearView = arguments.contains("-heatYearView")
    static let openSheet: String? = value(after: "-openSheet")
    static let inMemoryStore = arguments.contains("-inMemoryStore")
    #else
    static let startTab: AppSection? = nil
    static let openFirstTask = false
    static let heatYearView = false
    static let openSheet: String? = nil
    static let inMemoryStore = false
    #endif
}
