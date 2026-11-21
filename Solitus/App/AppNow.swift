import SwiftUI

/// "Now" as the screens need it: the local day and the minute of that day.
///
/// The root view refreshes it every minute and whenever the app comes
/// forward, so every screen recomputes "today" after a day rollover
/// (DESIGN.md 8.4). Equatable, so views redraw only when the minute changes.
nonisolated struct AppNow: Hashable, Sendable {
    var today: DayKey
    /// Minutes after local midnight, 0 to 1439.
    var minutes: Int

    init(today: DayKey, minutes: Int) {
        self.today = today
        self.minutes = minutes
    }

    init(clock: any AppClock) {
        self.today = clock.today
        self.minutes = clock.minutesAfterMidnight
    }
}

private struct AppNowKey: EnvironmentKey {
    static let defaultValue = AppNow(clock: SystemClock())
}

private struct AppClockKey: EnvironmentKey {
    static let defaultValue: any AppClock = SystemClock()
}

extension EnvironmentValues {
    var appNow: AppNow {
        get { self[AppNowKey.self] }
        set { self[AppNowKey.self] = newValue }
    }

    /// The injectable clock (DESIGN.md section 6).
    var appClock: any AppClock {
        get { self[AppClockKey.self] }
        set { self[AppClockKey.self] = newValue }
    }
}
