import Foundation

// The enums below are stored in SwiftData as their raw strings
// (DESIGN.md section 5). Do not rename a raw value without a migration.

/// Whether a task is something to do or something to avoid.
nonisolated enum TaskKind: String, CaseIterable, Sendable {
    case `do`
    case avoid
}

/// How often a task repeats (DESIGN.md 6.1).
nonisolated enum TaskPeriod: String, CaseIterable, Sendable {
    case daily, weekly, monthly
}

/// How a task's count is judged (DESIGN.md 6.2).
///
/// `exactly` and `atLeast` belong to Do tasks, `atMost` to Avoid tasks, and
/// `noLimit` to either.
nonisolated enum GoalMode: String, CaseIterable, Sendable {
    case exactly, atLeast, atMost, noLimit

    /// The goal modes offered for a kind, in the order the edit form shows.
    static func options(for kind: TaskKind) -> [GoalMode] {
        switch kind {
        case .do: return [.exactly, .atLeast, .noLimit]
        case .avoid: return [.atMost, .noLimit]
        }
    }
}

/// Which stat a Track card shows in its status line (DESIGN.md 8.1).
nonisolated enum QuickStat: String, CaseIterable, Sendable {
    case progress, avg30, avg90, streak
}
