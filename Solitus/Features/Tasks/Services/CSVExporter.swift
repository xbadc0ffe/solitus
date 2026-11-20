import Foundation

/// One line of the export: one entry.
nonisolated struct CSVRow: Hashable, Sendable {
    var taskName: String
    var kind: TaskKind
    var period: TaskPeriod
    var goalMode: GoalMode
    var target: Int
    var day: DayKey
    var count: Int
}

/// CSV export (DESIGN.md section 10). One row per entry:
/// `task_name, kind, period, goal_mode, target, date, count`.
nonisolated enum CSVExporter {
    static let header = ["task_name", "kind", "period", "goal_mode", "target", "date", "count"]

    /// The whole file. Rows are ordered by date, then task name. Lines end
    /// with CRLF, as spreadsheets expect.
    static func csv(_ rows: [CSVRow]) -> String {
        let ordered = rows.sorted { a, b in
            a.day != b.day ? a.day < b.day : a.taskName < b.taskName
        }
        var lines = [header.joined(separator: ",")]
        for row in ordered {
            lines.append(fields(for: row).map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func fields(for row: CSVRow) -> [String] {
        [
            text(row.taskName),
            row.kind.rawValue,
            row.period.rawValue,
            row.goalMode.rawValue,
            String(row.target),
            row.day.string,
            String(row.count),
        ]
    }

    /// Free text that starts with `=`, `+`, `-` or `@` would run as a
    /// formula when the file is opened in a spreadsheet. A leading
    /// apostrophe makes it plain text.
    static func text(_ value: String) -> String {
        guard let first = value.first, "=+-@".contains(first) else { return value }
        return "'" + value
    }

    /// Quotes a field only when it contains a comma, a quote or a line break.
    static func escape(_ field: String) -> String {
        let needsQuotes = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// The export rows for one task.
    static func rows(for history: TaskHistory) -> [CSVRow] {
        history.counts.map { day, count in
            CSVRow(
                taskName: history.name,
                kind: history.rules.kind,
                period: history.rules.period,
                goalMode: history.rules.goalMode,
                target: history.rules.target,
                day: day,
                count: count
            )
        }
    }

    /// The whole export for a set of tasks.
    static func csv(for histories: [TaskHistory]) -> String {
        csv(histories.flatMap { rows(for: $0) })
    }
}
