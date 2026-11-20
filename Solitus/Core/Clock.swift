import Foundation

/// The app's source of "now" (DESIGN.md section 6). Services never call
/// `Date()` themselves; they are handed a clock, so tests can pin the time.
///
/// The type is called `AppClock`, not `Clock`, because Swift's standard
/// library already has a `Clock` protocol.
nonisolated protocol AppClock: Sendable {
    var now: Date { get }
    /// A Gregorian calendar in the time zone that defines the local day.
    var calendar: Calendar { get }
}

nonisolated extension AppClock {
    /// The local calendar day right now.
    var today: DayKey {
        DayKey(date: now, calendar: calendar)
    }

    /// Minutes since local midnight, 0 to 1439.
    var minutesAfterMidnight: Int {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// The real clock: the device's time and current time zone.
nonisolated struct SystemClock: AppClock {
    var now: Date { Date() }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }
}

/// A clock frozen at one moment, for tests and previews.
nonisolated struct FixedClock: AppClock {
    var now: Date
    var calendar: Calendar

    init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    /// A clock at the given local time. The time zone defaults to UTC so
    /// tests give the same result on every machine.
    init(
        year: Int, month: Int, day: Int,
        hour: Int = 12, minute: Int = 0,
        timeZone: TimeZone? = TimeZone(identifier: "UTC")
    ) {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone {
            calendar.timeZone = timeZone
        }
        let key = DayKey(year: year, month: month, day: day)
        self.calendar = calendar
        self.now = key.date(in: calendar, hour: hour, minute: minute) ?? Date(timeIntervalSince1970: 0)
    }
}
