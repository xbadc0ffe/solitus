import Foundation
import Testing
@testable import Solitus

/// Heat (DESIGN.md 6.8).
struct HeatCalculatorTests {
    private let heat = HeatCalculator()

    @Test func stepsRoundToTheNearestOfSix() {
        #expect(HeatCalculator.step(for: 0) == 0)
        #expect(HeatCalculator.step(for: 0.09) == 0)
        #expect(HeatCalculator.step(for: 0.11) == 1)
        #expect(HeatCalculator.step(for: 0.5) == 3)
        #expect(HeatCalculator.step(for: 0.78) == 4)
        #expect(HeatCalculator.step(for: 1) == 5)
        #expect(HeatCalculator.step(for: 1.4) == 5)
        #expect(HeatCalculator.step(for: -0.2) == 0)
    }

    @Test func momentumStartsAtTheFirstDaysAmountAndDecays() throws {
        // A perfect first day, then nothing.
        let amounts: [DayKey: Double] = [nov(1): 1, nov(2): 0, nov(3): 0, nov(4): 0]
        let result = heat.heat(from: nov(1), to: nov(4)) { amounts[$0] }

        let first = try #require(result[nov(1)])
        #expect(isClose(first.momentum, 1))
        #expect(isClose(first.heat, 1))
        #expect(first.step == 5)

        // m = 0.55 * 1 = 0.55, k = 0.4 * 0.55 = 0.22
        let second = try #require(result[nov(2)])
        #expect(isClose(second.momentum, 0.55))
        #expect(isClose(second.heat, 0.22))
        #expect(second.step == 1)

        // m = 0.3025, k = 0.121
        let third = try #require(result[nov(3)])
        #expect(isClose(third.momentum, 0.3025))
        #expect(isClose(third.heat, 0.121))
        #expect(third.step == 1)

        // m = 0.166375, k = 0.06655
        let fourth = try #require(result[nov(4)])
        #expect(isClose(fourth.heat, 0.06655))
        #expect(fourth.step == 0)
    }

    @Test func oneDayAfterALongGapIsOnlyWarm() throws {
        var amounts: [DayKey: Double] = [:]
        for d in 1...10 {
            amounts[nov(d)] = 0
        }
        amounts[nov(11)] = 1
        let result = heat.heat(from: nov(1), to: nov(11)) { amounts[$0] }
        // m = 0.45, k = 0.6 + 0.4 * 0.45 = 0.78
        let value = try #require(result[nov(11)])
        #expect(isClose(value.heat, 0.78))
        #expect(value.step == 4)
    }

    @Test func sustainedEffortReachesFullHeat() throws {
        var amounts: [DayKey: Double] = [nov(1): 0]
        for d in 2...15 {
            amounts[nov(d)] = 1
        }
        let result = heat.heat(from: nov(1), to: nov(15)) { amounts[$0] }
        #expect(result[nov(15)]?.step == 5)
    }

    @Test func daysWithNoAmountAreLeftOutAndKeepMomentum() throws {
        let amounts: [DayKey: Double] = [nov(1): 1, nov(3): 0]
        let result = heat.heat(from: nov(1), to: nov(3)) { amounts[$0] }
        #expect(result[nov(2)] == nil)
        #expect(result.count == 2)
        // Momentum carried straight from Nov 1 to Nov 3.
        #expect(isClose(result[nov(3)]?.momentum, 0.55))
    }

    @Test func doTaskHeatUsesTheDailyValue() throws {
        let task = TaskHistory(
            rules: TaskRules(goalMode: .exactly, target: 2, createdDay: nov(18)),
            counts: [nov(18): 2, nov(19): 1]
        )
        let result = heat.heat(for: task, today: today)
        #expect(result.count == 3)
        #expect(result[nov(17)] == nil)
        #expect(isClose(result[nov(18)]?.amount, 1))
        #expect(isClose(result[nov(19)]?.amount, 0.5))
        #expect(isClose(result[nov(20)]?.amount, 0))
    }

    @Test func automaticHeatMaxIsTheLargestRecentCountWithAFloor() {
        let rules = TaskRules(goalMode: .noLimit, createdDay: day(2026, 1, 1))
        #expect(heat.heatMax(for: TaskHistory(rules: rules, counts: [:]), today: today) == 3)
        #expect(heat.heatMax(for: TaskHistory(rules: rules, counts: [nov(5): 2]), today: today) == 3)
        #expect(heat.heatMax(for: TaskHistory(rules: rules, counts: [nov(5): 7, nov(9): 4]), today: today) == 7)
        // A big day more than 90 days ago no longer counts.
        let old: DayCounts = [today.adding(-100): 10, nov(5): 4]
        #expect(heat.heatMax(for: TaskHistory(rules: rules, counts: old), today: today) == 4)
        // The last day inside the window is 89 days back.
        let edge: DayCounts = [today.adding(-89): 10]
        #expect(heat.heatMax(for: TaskHistory(rules: rules, counts: edge), today: today) == 10)
    }

    @Test func fixedHeatMaxWins() {
        var rules = TaskRules(goalMode: .noLimit, createdDay: nov(1))
        rules.heatMax = 5
        let task = TaskHistory(rules: rules, counts: [nov(5): 20])
        #expect(heat.heatMax(for: task, today: today) == 5)
    }

    @Test func noLimitHeatIsCountOverHeatMax() {
        let rules = TaskRules(goalMode: .noLimit, createdDay: nov(1))
        let task = TaskHistory(rules: rules, counts: [nov(5): 2, nov(6): 9])
        #expect(isClose(heat.amount(for: task, day: nov(5), today: today, heatMax: 4), 0.5))
        #expect(isClose(heat.amount(for: task, day: nov(6), today: today, heatMax: 4), 1))
        #expect(isClose(heat.amount(for: task, day: nov(7), today: today, heatMax: 4), 0))
        #expect(heat.amount(for: task, day: day(2026, 10, 31), today: today, heatMax: 4) == nil)
        #expect(heat.amount(for: task, day: nov(21), today: today, heatMax: 4) == nil)
    }

    @Test func avoidHeatShowsOccurrences() throws {
        // Default for open question 12.1: hot means it happened.
        let rules = TaskRules(kind: .avoid, goalMode: .atMost, target: 0, createdDay: nov(18))
        let task = TaskHistory(rules: rules, counts: [nov(19): 3])
        let result = heat.heat(for: task, today: today)
        #expect(result[nov(18)]?.step == 0)
        #expect(isClose(result[nov(19)]?.amount, 1))
        #expect((result[nov(19)]?.step ?? 0) >= 3)
    }

    @Test func allTasksHeatIsTheMeanDailyValueOfScoredTasks() throws {
        let done = TaskHistory(rules: TaskRules(createdDay: nov(19)), counts: ones(19, 20))
        let missed = TaskHistory(rules: TaskRules(createdDay: nov(19)), counts: [:])
        let unscored = TaskHistory(rules: TaskRules(goalMode: .noLimit, createdDay: nov(1)), counts: ones(19))
        var archivedRules = TaskRules(createdDay: nov(1))
        archivedRules.isArchived = true
        let archived = TaskHistory(rules: archivedRules, counts: ones(19, 20))

        let result = heat.allTasksHeat([done, missed, unscored, archived], today: today)
        // Only the two scored, unarchived tasks count, from Nov 19.
        #expect(result.count == 2)
        #expect(isClose(result[nov(19)]?.amount, 0.5))
        #expect(isClose(result[nov(20)]?.amount, 0.5))
    }

    @Test func allTasksHeatIsEmptyWithNoScoredTasks() {
        let unscored = TaskHistory(rules: TaskRules(goalMode: .noLimit, createdDay: nov(1)), counts: ones(19))
        #expect(heat.allTasksHeat([unscored], today: today).isEmpty)
        #expect(heat.allTasksHeat([], today: today).isEmpty)
    }
}
