import Foundation
import Testing
@testable import Solitus

/// CSV export (DESIGN.md section 10).
struct CSVExporterTests {
    private func row(_ name: String, _ day: DayKey, _ count: Int) -> CSVRow {
        CSVRow(taskName: name, kind: .do, period: .daily, goalMode: .exactly, target: 3, day: day, count: count)
    }

    @Test func headerNamesTheSevenColumns() {
        #expect(CSVExporter.header == ["task_name", "kind", "period", "goal_mode", "target", "date", "count"])
        #expect(CSVExporter.fields(for: row("Medication", today, 1)).count == CSVExporter.header.count)
    }

    @Test func escapesOnlyWhenNeeded() {
        #expect(CSVExporter.escape("plain") == "plain")
        #expect(CSVExporter.escape("a,b") == "\"a,b\"")
        #expect(CSVExporter.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVExporter.escape("two\nlines") == "\"two\nlines\"")
    }

    @Test func formulaLikeNamesAreNeutralised() {
        #expect(CSVExporter.text("=SUM(A1:A2)") == "'=SUM(A1:A2)")
        #expect(CSVExporter.text("-1 coffee") == "'-1 coffee")
        #expect(CSVExporter.text("+2") == "'+2")
        #expect(CSVExporter.text("@home") == "'@home")
        #expect(CSVExporter.text("Walk") == "Walk")
        #expect(CSVExporter.text("") == "")
    }

    @Test func writesOneLinePerEntryInDateOrder() {
        let rows = [
            row("Walk", nov(20), 1),
            row("Medication", nov(20), 2),
            row("Walk", nov(19), 1),
        ]
        let expected = [
            "task_name,kind,period,goal_mode,target,date,count",
            "Walk,do,daily,exactly,3,2026-11-19,1",
            "Medication,do,daily,exactly,3,2026-11-20,2",
            "Walk,do,daily,exactly,3,2026-11-20,1",
        ].joined(separator: "\r\n") + "\r\n"
        #expect(CSVExporter.csv(rows) == expected)
    }

    @Test func emptyExportIsJustTheHeader() {
        #expect(CSVExporter.csv([]) == "task_name,kind,period,goal_mode,target,date,count\r\n")
    }

    @Test func rawValuesAreWrittenForEveryEnum() {
        let avoid = CSVRow(taskName: "Drinks, wine", kind: .avoid, period: .weekly, goalMode: .atMost, target: 0, day: today, count: 2)
        #expect(CSVExporter.fields(for: avoid) == ["Drinks, wine", "avoid", "weekly", "atMost", "0", "2026-11-20", "2"])
        #expect(CSVExporter.csv([avoid]).contains("\"Drinks, wine\",avoid,weekly,atMost,0,2026-11-20,2"))
    }

    @Test func buildsRowsFromATasksHistory() {
        let history = TaskHistory(
            name: "Gym",
            rules: TaskRules(period: .weekly, goalMode: .exactly, target: 4, createdDay: nov(1)),
            counts: [nov(16): 1, nov(18): 2]
        )
        let rows = CSVExporter.rows(for: history).sorted { $0.day < $1.day }
        #expect(rows.count == 2)
        #expect(rows.first == CSVRow(taskName: "Gym", kind: .do, period: .weekly, goalMode: .exactly, target: 4, day: nov(16), count: 1))
        #expect(CSVExporter.csv(for: [history]).hasSuffix("Gym,do,weekly,exactly,4,2026-11-18,2\r\n"))
    }
}
