import Foundation
import Testing
@testable import Solitus

@Suite struct TrendDataTests {
    private let data = TrendData(calc: TaskCalc(), today: today)

    private func history(_ name: String, created: DayKey, counts: DayCounts = [:], mode: GoalMode = .exactly) -> TaskHistory {
        TaskHistory(name: name, rules: TaskRules(goalMode: mode, createdDay: created), counts: counts)
    }

    @Test func theGraphStartsAtTheEarliestScoredTask() {
        let histories = [
            history("A", created: day(2026, 6, 1)),
            history("B", created: day(2026, 9, 1)),
            history("Unscored", created: day(2026, 1, 1), mode: .noLimit),
        ]
        #expect(data.firstDay(histories, window: 30) == day(2026, 6, 1))
    }

    @Test func theGraphAlwaysCoversOneWindow() {
        // A task created yesterday still gets a full 30-day axis.
        let histories = [history("New", created: nov(19))]
        #expect(data.firstDay(histories, window: 30) == today.adding(-29))
        #expect(data.firstDay([], window: 90) == today.adding(-89))
    }

    @Test func historyIsCappedAtTwoYears() {
        let histories = [history("Old", created: day(2020, 1, 1))]
        #expect(data.firstDay(histories, window: 30) == today.adding(-TrendData.maxHistoryDays))
    }

    @Test func defaultLinesAreTotalBestAndWorst() {
        let histories = [
            history("Always", created: nov(11), counts: ones(11, 12, 13, 14, 15, 16, 17, 18, 19, 20)),
            history("Never", created: nov(11)),
        ]
        let lines = data.defaultLines(histories, window: 30, groupSize: 1)
        #expect(lines.map(\.id) == [TrendLine.totalID, TrendLine.bestID, TrendLine.worstID])
        #expect(lines.map(\.name) == ["Total", "Best 1", "Worst 1"])
        #expect(isClose(lines[0].current, 0.5))
        #expect(isClose(lines[1].current, 1))
        #expect(isClose(lines[2].current, 0))
        // Every line ends today and spans the whole window.
        #expect(lines.allSatisfy { $0.points.last?.day == today && $0.points.count == 30 })
    }

    @Test func summaryNamesEachLine() {
        let lines = data.defaultLines([history("Always", created: nov(20), counts: ones(20))], window: 30, groupSize: 5)
        #expect(TrendData.summary(lines) == "Total 100%, Best 5 100%, Worst 5 100%")
    }

    @Test func sheetStateSurvivesARoundTrip() {
        var state = TrendSheetState()
        state.hidden = [TrendLine.worstID]
        state.taskIDs = [UUID(), UUID()]
        #expect(TrendSheetState(json: state.json) == state)
        // Unreadable text gives the default state.
        #expect(TrendSheetState(json: "not json") == TrendSheetState())
        #expect(TrendSheetState(json: "") == TrendSheetState())
    }
}
