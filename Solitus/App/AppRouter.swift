import Foundation
import Observation

/// A page that pops up over the current screen (DESIGN.md 7.6).
enum SheetRoute: Identifiable {
    case addTask
    case editTask(TaskItem)
    case trendGraph

    var id: String {
        switch self {
        case .addTask: return "add"
        case .editTask(let task): return "edit-" + task.id.uuidString
        case .trendGraph: return "trend"
        }
    }
}

/// App-wide navigation state that is not owned by one screen: which sheet is
/// up, and a counter that tells the root view the data changed.
@Observable
final class AppRouter {
    var sheet: SheetRoute?

    /// Goes up whenever a task or an entry changes, so reminders are rebuilt
    /// (DESIGN.md section 10).
    private(set) var changeCount = 0

    func dataChanged() {
        changeCount += 1
    }
}
