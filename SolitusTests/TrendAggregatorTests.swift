import Foundation
import Testing
@testable import Solitus

/// Trends aggregates (DESIGN.md 6.6).
struct TrendAggregatorTests {
    private let trends = TrendAggregator()

    /// A daily task created Nov 11 (ten days of life) that was done on the
    /// first `done` of those days, so its average is `done / 10`.
    private func task(_ name: String, done: Int, archived: Bool = false) -> TaskHistory {
        var counts: DayCounts = [:]
        for offset in 0..<done {
            counts[nov(11 + offset)] = 1
        }
        var rules = TaskRules(createdDay: nov(11))
        rules.isArchived = archived
        return TaskHistory(name: name, rules: rules, counts: counts)
    }

    private var unscored: TaskHistory {
        TaskHistory(name: "Journal", rules: TaskRules(goalMode: .noLimit, createdDay: nov(11)), counts: ones(11, 12))
    }

    @Test func totalAverageIsTheMeanOfTaskAverages() {
        let tasks = [task("A", done: 10), task("B", done: 5), task("C", done: 0)]
        let total = trends.totalAverage(tasks, window: 30, endingOn: today, today: today)
        #expect(isClose(total, 0.5))
    }

    @Test func totalAverageLeavesOutUnscoredAndArchivedTasks() {
        let tasks = [task("A", done: 10), unscored, task("Old", done: 0, archived: true)]
        let total = trends.totalAverage(tasks, window: 30, endingOn: today, today: today)
        #expect(isClose(total, 1))
    }

    @Test func totalAverageIsUndefinedWithNoEligibleTasks() {
        #expect(trends.totalAverage([], window: 30, endingOn: today, today: today) == nil)
        #expect(trends.totalAverage([unscored], window: 30, endingOn: today, today: today) == nil)
    }

    @Test func groupsTakeTheTopAndBottomK() {
        let tasks = [
            task("A", done: 2), task("B", done: 9), task("C", done: 5),
            task("D", done: 7), task("E", done: 0), task("F", done: 10),
        ]
        let groups = trends.groups(tasks, window: 30, today: today, groupSize: 2)
        #expect(groups.best == [tasks[5].id, tasks[1].id])
        #expect(groups.worst == [tasks[4].id, tasks[0].id])
    }

    @Test func groupsContainEveryTaskWhenThereAreFewerThanK() {
        let tasks = [task("A", done: 2), task("B", done: 9), task("C", done: 5)]
        let groups = trends.groups(tasks, window: 30, today: today, groupSize: 5)
        #expect(groups.best.count == 3)
        #expect(groups.worst.count == 3)
        #expect(Set(groups.best) == Set(groups.worst))
        #expect(groups.best.first == tasks[1].id)
        #expect(groups.worst.first == tasks[0].id)
    }

    @Test func groupsIgnoreUnscoredAndArchivedTasks() {
        let kept = task("A", done: 4)
        let groups = trends.groups([kept, unscored, task("Old", done: 10, archived: true)], window: 30, today: today, groupSize: 5)
        #expect(groups.best == [kept.id])
        #expect(groups.worst == [kept.id])
    }

    @Test func tiesKeepTheInputOrder() {
        let tasks = [task("A", done: 5), task("B", done: 5), task("C", done: 5)]
        let groups = trends.groups(tasks, window: 30, today: today, groupSize: 2)
        #expect(groups.best == [tasks[0].id, tasks[1].id])
        #expect(groups.worst == [tasks[0].id, tasks[1].id])
    }

    @Test func meanSeriesAveragesTheMembersOnEveryDay() {
        let tasks = [task("A", done: 10), task("B", done: 0)]
        let series = trends.meanSeries(tasks, window: 30, from: nov(9), to: today, today: today)
        #expect(series.count == 12)
        // Before either task existed there is nothing to average.
        #expect(series[0].value == nil)
        #expect(series[1].value == nil)
        // From Nov 11 one task is at 1 and the other at 0.
        for point in series.dropFirst(2) {
            #expect(isClose(point.value, 0.5))
        }
        #expect(series.last?.day == today)
    }

    @Test func meanSeriesOfNoTasksIsAllUndefined() {
        let series = trends.meanSeries([], window: 30, from: nov(18), to: today, today: today)
        #expect(series.count == 3)
        #expect(series.allSatisfy { $0.value == nil })
    }

    @Test func topStreaksAreTheLongestCurrentStreaks() {
        func streaky(_ name: String, lastDays: Int) -> TaskHistory {
            var counts: DayCounts = [:]
            for offset in 0..<lastDays {
                counts[today.adding(-offset)] = 1
            }
            return TaskHistory(name: name, rules: TaskRules(createdDay: nov(1)), counts: counts)
        }
        let tasks = [streaky("A", lastDays: 2), streaky("B", lastDays: 9), streaky("C", lastDays: 0), streaky("D", lastDays: 5), streaky("E", lastDays: 4)]
        let top = trends.topStreaks(tasks, today: today)
        #expect(top.map { $0.name } == ["B", "D", "E"])
        #expect(top.map { $0.current } == [9, 5, 4])
    }

    @Test func topStreaksLeaveOutTasksWithNoStreak() {
        let idle = TaskHistory(name: "Idle", rules: TaskRules(createdDay: nov(1)), counts: [:])
        #expect(trends.topStreaks([idle], today: today).isEmpty)
    }
}
