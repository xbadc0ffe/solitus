import Foundation
import Testing
@testable import Solitus

/// `DayKey`: the day arithmetic everything else stands on.
struct DayKeyTests {
    @Test func epochIsThursdayAndOrdinalZero() {
        let epoch = day(1970, 1, 1)
        #expect(epoch.ordinal == 0)
        #expect(epoch.weekday == 5)
        #expect(epoch.string == "1970-01-01")
    }

    @Test func mockupDateIsAFriday() {
        let date = day(2026, 11, 20)
        #expect(date.weekday == 6)
        #expect(date.year == 2026)
        #expect(date.month == 11)
        #expect(date.day == 20)
        #expect(date.string == "2026-11-20")
        #expect(day(2026, 11, 1).weekday == 1)
    }

    @Test func componentsRoundTripAcrossCenturies() {
        for ordinal in stride(from: -800_000, through: 800_000, by: 997) {
            let key = DayKey(ordinal: ordinal)
            let rebuilt = DayKey(year: key.year, month: key.month, day: key.day)
            #expect(rebuilt.ordinal == ordinal)
        }
    }

    @Test func consecutiveOrdinalsAreConsecutiveDays() {
        var previous = day(2023, 12, 30)
        for _ in 0..<800 {
            let next = previous.adding(1)
            let sameMonth = next.month == previous.month && next.year == previous.year
            if sameMonth {
                #expect(next.day == previous.day + 1)
            } else {
                #expect(next.day == 1)
                #expect(previous.day == DayKey.daysInMonth(year: previous.year, month: previous.month))
            }
            #expect(next.weekday == previous.weekday % 7 + 1)
            previous = next
        }
    }

    @Test func parsesOnlyRealDates() {
        #expect(DayKey(string: "2026-11-20") == day(2026, 11, 20))
        #expect(DayKey(string: "2028-02-29") == day(2028, 2, 29))
        #expect(DayKey(string: "2026-02-29") == nil)
        #expect(DayKey(string: "2026-13-01") == nil)
        #expect(DayKey(string: "2026-00-10") == nil)
        #expect(DayKey(string: "2026-11-31") == nil)
        #expect(DayKey(string: "2026-11") == nil)
        #expect(DayKey(string: "not a date") == nil)
        #expect(DayKey(string: "") == nil)
    }

    @Test func stringRoundTrips() {
        let key = day(2027, 3, 5)
        #expect(key.string == "2027-03-05")
        #expect(DayKey(string: key.string) == key)
    }

    @Test func addsAcrossMonthAndYearEnds() {
        #expect(day(2026, 12, 31).adding(1) == day(2027, 1, 1))
        #expect(day(2028, 2, 28).adding(1) == day(2028, 2, 29))
        #expect(day(2026, 2, 28).adding(1) == day(2026, 3, 1))
        #expect(day(2026, 3, 1).adding(-1) == day(2026, 2, 28))
        #expect(day(2026, 11, 20).adding(-20) == day(2026, 10, 31))
    }

    @Test func measuresDaysBetween() {
        #expect(day(2026, 11, 1).days(until: day(2026, 11, 20)) == 19)
        #expect(day(2026, 11, 20).days(until: day(2026, 11, 1)) == -19)
        #expect(day(2026, 1, 1).days(until: day(2027, 1, 1)) == 365)
        #expect(day(2028, 1, 1).days(until: day(2029, 1, 1)) == 366)
    }

    @Test func comparesInTimeOrder() {
        #expect(day(2026, 11, 19) < day(2026, 11, 20))
        #expect(day(2025, 12, 31) < day(2026, 1, 1))
        #expect([day(2026, 3, 1), day(2026, 1, 1), day(2026, 2, 1)].sorted() == [day(2026, 1, 1), day(2026, 2, 1), day(2026, 3, 1)])
    }

    @Test func monthLengthsAndLeapYears() {
        #expect(DayKey.daysInMonth(year: 2026, month: 2) == 28)
        #expect(DayKey.daysInMonth(year: 2028, month: 2) == 29)
        #expect(DayKey.daysInMonth(year: 2100, month: 2) == 28)
        #expect(DayKey.daysInMonth(year: 2000, month: 2) == 29)
        #expect(DayKey.daysInMonth(year: 2026, month: 11) == 30)
        #expect(DayKey.daysInMonth(year: 2026, month: 12) == 31)
    }

    @Test func localDayDependsOnTimeZone() throws {
        // 23:30 on Nov 20 in Los Angeles is already Nov 21 in UTC.
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let clock = FixedClock(year: 2026, month: 11, day: 20, hour: 23, minute: 30, timeZone: losAngeles)
        #expect(clock.today == day(2026, 11, 20))
        #expect(clock.minutesAfterMidnight == 23 * 60 + 30)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(DayKey(date: clock.now, calendar: utc) == day(2026, 11, 21))
    }

    @Test func convertsBackToADate() throws {
        let clock = FixedClock(year: 2026, month: 11, day: 20, hour: 9, minute: 0)
        let date = try #require(day(2026, 11, 20).date(in: clock.calendar, hour: 9, minute: 0))
        #expect(date == clock.now)
    }
}
