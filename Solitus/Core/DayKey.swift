import Foundation

/// One calendar day in the proleptic Gregorian calendar, with no time zone.
///
/// Entries are stored per day as a `yyyy-MM-dd` string (DESIGN.md 5.2), so a
/// change of time zone never moves an entry to another day. `DayKey` is the
/// in-memory form of that string. It stores the number of days since
/// 1970-01-01, which makes adding days, comparing and finding the weekday
/// plain integer maths with no `Calendar` and nothing that can fail.
///
/// A `Calendar` is only needed at the two edges: turning "now" into a
/// `DayKey` (`init(date:calendar:)`) and turning a `DayKey` back into a
/// `Date` for a notification or a label (`date(in:hour:minute:)`).
nonisolated struct DayKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Days since 1970-01-01. Negative for earlier days.
    let ordinal: Int

    init(ordinal: Int) {
        self.ordinal = ordinal
    }

    /// Builds a day from civil components. Out-of-range values are not
    /// validated here; use `init?(string:)` for untrusted input.
    init(year: Int, month: Int, day: Int) {
        self.ordinal = DayKey.ordinal(year: year, month: month, day: day)
    }

    /// Parses `yyyy-MM-dd`. Returns nil for anything that is not a real date.
    init?(string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              day >= 1,
              day <= DayKey.daysInMonth(year: year, month: month)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The local day that `date` falls on in `calendar`'s time zone. Pass a
    /// Gregorian calendar (the app's clocks always do).
    init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    // MARK: Components

    var year: Int { DayKey.civil(fromOrdinal: ordinal).year }
    var month: Int { DayKey.civil(fromOrdinal: ordinal).month }
    var day: Int { DayKey.civil(fromOrdinal: ordinal).day }

    /// 1 (Sunday) to 7 (Saturday), matching `Calendar`'s numbering.
    var weekday: Int {
        // 1970-01-01 was a Thursday (weekday 5).
        let remainder = ((ordinal % 7) + 7) % 7
        return (remainder + 4) % 7 + 1
    }

    /// The stored form, `yyyy-MM-dd`.
    var string: String {
        let parts = DayKey.civil(fromOrdinal: ordinal)
        return String(format: "%04d-%02d-%02d", parts.year, parts.month, parts.day)
    }

    var description: String { string }

    // MARK: Arithmetic

    func adding(_ days: Int) -> DayKey {
        DayKey(ordinal: ordinal + days)
    }

    /// Whole days from this day to `other`. Negative if `other` is earlier.
    func days(until other: DayKey) -> Int {
        other.ordinal - ordinal
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    /// A `Date` on this day at the given local time, or nil if the calendar
    /// cannot produce one.
    func date(in calendar: Calendar, hour: Int = 12, minute: Int = 0) -> Date? {
        let parts = DayKey.civil(fromOrdinal: ordinal)
        var components = DateComponents()
        components.year = parts.year
        components.month = parts.month
        components.day = parts.day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    // MARK: Calendar maths

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 30
        }
    }

    // The two functions below are the standard "days from civil" and
    // "civil from days" algorithms (Howard Hinnant). They are exact for the
    // whole Gregorian calendar and rely on integer division truncating.

    private static func ordinal(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func civil(fromOrdinal ordinal: Int) -> (year: Int, month: Int, day: Int) {
        let z = ordinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }
}
