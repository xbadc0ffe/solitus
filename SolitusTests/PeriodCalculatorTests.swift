import Foundation
import Testing
@testable import Solitus

/// Periods (DESIGN.md 6.1).
struct PeriodCalculatorTests {
    @Test func dailySpanIsOneDay() {
        let span = PeriodCalculator().span(containing: today, period: .daily)
        #expect(span.start == today)
        #expect(span.end == today)
        #expect(span.dayCount == 1)
    }

    @Test func weekStartsOnSundayByDefault() {
        let span = PeriodCalculator().span(containing: today, period: .weekly)
        #expect(span.start == nov(15))
        #expect(span.end == nov(21))
        #expect(span.dayCount == 7)
    }

    @Test func weekCanStartOnAnyDay() {
        // Monday start.
        let monday = PeriodCalculator(weekStart: 2).span(containing: today, period: .weekly)
        #expect(monday.start == nov(16))
        #expect(monday.end == nov(22))
        // Friday start: the week begins on the day itself.
        let friday = PeriodCalculator(weekStart: 6).span(containing: today, period: .weekly)
        #expect(friday.start == nov(20))
        // Saturday start: the week began six days ago.
        let saturday = PeriodCalculator(weekStart: 7).span(containing: today, period: .weekly)
        #expect(saturday.start == nov(14))
        #expect(saturday.end == nov(20))
    }

    @Test func everyDayOfAWeekMapsToTheSameWeek() {
        let calculator = PeriodCalculator()
        for d in 15...21 {
            #expect(calculator.span(containing: nov(d), period: .weekly).start == nov(15))
        }
        #expect(calculator.span(containing: nov(22), period: .weekly).start == nov(22))
    }

    @Test func weekStartIsClamped() {
        #expect(PeriodCalculator(weekStart: 0).weekStart == 1)
        #expect(PeriodCalculator(weekStart: 9).weekStart == 7)
    }

    @Test func monthlySpanIsTheCalendarMonth() {
        let calculator = PeriodCalculator()
        let november = calculator.span(containing: today, period: .monthly)
        #expect(november.start == nov(1))
        #expect(november.end == nov(30))
        #expect(november.dayCount == 30)

        let leapFebruary = calculator.span(containing: day(2028, 2, 10), period: .monthly)
        #expect(leapFebruary.end == day(2028, 2, 29))
        #expect(leapFebruary.dayCount == 29)
    }

    @Test func nextAndPreviousCrossYearEnds() {
        let calculator = PeriodCalculator()
        let december = calculator.span(containing: day(2026, 12, 15), period: .monthly)
        let january = calculator.next(after: december, period: .monthly)
        #expect(january.start == day(2027, 1, 1))
        #expect(january.end == day(2027, 1, 31))
        #expect(calculator.previous(before: january, period: .monthly) == december)

        let week = calculator.span(containing: today, period: .weekly)
        #expect(calculator.next(after: week, period: .weekly).start == nov(22))
        #expect(calculator.previous(before: week, period: .weekly).start == nov(8))
    }

    @Test func periodCountSumsItsDays() {
        let calculator = PeriodCalculator()
        let counts: DayCounts = [nov(14): 5, nov(15): 1, nov(18): 2, nov(21): 1, nov(22): 7]
        #expect(calculator.count(containing: today, period: .daily, counts: counts) == 0)
        #expect(calculator.count(containing: nov(18), period: .daily, counts: counts) == 2)
        #expect(calculator.count(containing: today, period: .weekly, counts: counts) == 4)
        #expect(calculator.count(containing: today, period: .monthly, counts: counts) == 16)
    }

    @Test func changingWeekStartRegroupsHistory() {
        // The same entries land in different weeks; nothing is stored per week.
        let counts: DayCounts = [nov(15): 1, nov(16): 1]
        #expect(PeriodCalculator(weekStart: 1).count(containing: nov(16), period: .weekly, counts: counts) == 2)
        #expect(PeriodCalculator(weekStart: 2).count(containing: nov(16), period: .weekly, counts: counts) == 1)
    }

    @Test func spanListsItsDays() {
        let span = PeriodSpan(start: nov(29), end: day(2026, 12, 1))
        #expect(span.days == [nov(29), nov(30), day(2026, 12, 1)])
        #expect(span.contains(nov(30)))
        #expect(!span.contains(nov(28)))
    }
}
