import Foundation
import Testing
@testable import Solitus

/// Running averages (DESIGN.md 6.5).
struct RunningAverageTests {
    private let averages = RunningAverage()

    private func dailyTask(created: DayKey, counts: DayCounts) -> TaskHistory {
        TaskHistory(rules: TaskRules(createdDay: created), counts: counts)
    }

    @Test func averagesTheWindowAndSkipsDaysWithNoValue() {
        // Values for the three days ending on Nov 20: 1, 0 and none.
        let values: [DayKey: Double] = [nov(20): 1, nov(19): 0]
        let result = averages.average(window: 3, endingOn: today) { values[$0] }
        #expect(isClose(result, 0.5))
    }

    @Test func isUndefinedWhenNoDayHasAValue() {
        let result = averages.average(window: 30, endingOn: today) { _ in nil }
        #expect(result == nil)
    }

    @Test func onlyLooksInsideTheWindow() {
        // A perfect day just outside a 3-day window is ignored.
        let values: [DayKey: Double] = [nov(17): 1, nov(18): 0, nov(19): 0, nov(20): 0]
        #expect(isClose(averages.average(window: 3, endingOn: today) { values[$0] }, 0))
        #expect(isClose(averages.average(window: 4, endingOn: today) { values[$0] }, 0.25))
    }

    @Test func taskAverageSkipsDaysBeforeItWasCreated() {
        // Created Nov 11: ten days of life, five done. The 30-day window
        // divides by ten, not thirty.
        let task = dailyTask(created: nov(11), counts: ones(11, 13, 15, 17, 19))
        #expect(isClose(averages.average(for: task, window: 30, endingOn: today, today: today), 0.5))
        #expect(isClose(averages.average(for: task, window: 90, endingOn: today, today: today), 0.5))
    }

    @Test func noLimitTaskHasNoAverage() {
        let rules = TaskRules(goalMode: .noLimit, createdDay: nov(1))
        let task = TaskHistory(rules: rules, counts: ones(5, 6))
        #expect(averages.average(for: task, window: 30, endingOn: today, today: today) == nil)
    }

    @Test func seriesHasOnePointPerDayEndingOnThatDay() {
        let task = dailyTask(created: nov(1), counts: ones(1, 2, 3, 4, 8, 9, 15, 16, 17, 20))
        let series = averages.series(for: task, window: 7, from: nov(5), to: today, today: today)
        #expect(series.count == 16)
        #expect(series.first?.day == nov(5))
        #expect(series.last?.day == today)

        // Every point must equal the directly computed average for its day.
        for point in series {
            let direct = averages.average(for: task, window: 7, endingOn: point.day, today: today)
            if let direct {
                #expect(isClose(point.value, direct))
            } else {
                #expect(point.value == nil)
            }
        }
    }

    @Test func seriesIsUndefinedBeforeTheTaskExists() {
        let task = dailyTask(created: nov(10), counts: ones(10))
        let series = averages.series(for: task, window: 3, from: nov(5), to: nov(11), today: today)
        #expect(series.count == 7)
        // Windows ending Nov 5 to Nov 9 contain no day with a value.
        for point in series.prefix(5) {
            #expect(point.value == nil)
        }
        #expect(isClose(series[5].value, 1))    // Nov 10 alone
        #expect(isClose(series[6].value, 0.5))  // Nov 10 and 11
    }

    @Test func emptyRangeGivesNoPoints() {
        let task = dailyTask(created: nov(1), counts: [:])
        #expect(averages.series(for: task, window: 30, from: nov(10), to: nov(9), today: today).isEmpty)
    }

    @Test func fillLevelReachesFullAtTheTasksThreshold() {
        #expect(isClose(RunningAverage.fillLevel(average: 0.85, fullAt: 0.85), 1))
        #expect(isClose(RunningAverage.fillLevel(average: 1.0, fullAt: 0.85), 1))
        #expect(isClose(RunningAverage.fillLevel(average: 0.425, fullAt: 0.85), 0.5))
        #expect(isClose(RunningAverage.fillLevel(average: 0, fullAt: 0.85), 0))
        #expect(isClose(RunningAverage.fillLevel(average: 0.5, fullAt: 1.0), 0.5))
    }
}
