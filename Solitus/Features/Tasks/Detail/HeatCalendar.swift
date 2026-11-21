import SwiftUI

/// The heat calendar (DESIGN.md 7.3): a title bar with previous and next
/// arrows over either a month of numbered day cells or a year of month
/// tiles. Tapping the title switches between the two.
///
/// Used on Task details with one task's heat and on Trends with all-tasks
/// heat (DESIGN.md 6.8).
struct HeatCalendar: View {
    enum Mode { case month, year }

    let heat: [DayKey: HeatValue]
    let today: DayKey
    /// 1 (Sunday) to 7.
    let weekStart: Int

    @Environment(\.slTheme) private var theme

    @State private var mode: Mode
    @State private var year: Int
    @State private var month: Int

    init(heat: [DayKey: HeatValue], today: DayKey, weekStart: Int, initialMode: Mode = .month) {
        self.heat = heat
        self.today = today
        self.weekStart = min(max(weekStart, 1), 7)
        _mode = State(initialValue: initialMode)
        _year = State(initialValue: today.year)
        _month = State(initialValue: today.month)
    }

    /// Month and weekday names in the user's language.
    private static let symbols: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.autoupdatingCurrent
        return calendar
    }()

    var body: some View {
        VStack(spacing: 8) {
            titleBar
            switch mode {
            case .month: monthView
            case .year:
                YearHeatView(heat: heat, today: today, weekStart: weekStart, year: year) { chosen in
                    month = chosen
                    withAnimation(.easeInOut(duration: 0.2)) { mode = .month }
                }
            }
        }
        .padding(.horizontal, theme.metrics.innerPadding)
        .padding(.top, 6)
        .padding(.bottom, theme.metrics.innerPadding)
        .background(SLSurface(role: .panel))
    }

    // MARK: Title bar

    private var title: String {
        switch mode {
        case .month: return "\(HeatCalendar.monthName(month)) \(String(year))"
        case .year: return String(year)
        }
    }

    /// Nothing lies beyond the current month or year.
    private var canGoForward: Bool {
        switch mode {
        case .month: return (year, month) < (today.year, today.month)
        case .year: return year < today.year
        }
    }

    private var titleBar: some View {
        let palette = theme.palette
        let tap = theme.metrics.minTapTarget
        return HStack(spacing: 0) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: tap, height: tap)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(mode == .month ? "Previous month" : "Previous year")

            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = mode == .month ? .year : .month
                }
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(minHeight: tap)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .accessibilityHint(mode == .month ? "Shows the year" : "Shows the month")
            Spacer(minLength: 0)

            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: tap, height: tap)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.35)
            .accessibilityLabel(mode == .month ? "Next month" : "Next year")
        }
        .buttonStyle(.plain)
        .font(theme.font(.body).weight(.semibold))
        .foregroundStyle(palette.textPrimary)
    }

    private func step(_ direction: Int) {
        switch mode {
        case .year:
            year += direction
        case .month:
            var next = month + direction
            if next < 1 {
                next = 12
                year -= 1
            } else if next > 12 {
                next = 1
                year += 1
            }
            month = next
        }
    }

    // MARK: Month view

    private var monthView: some View {
        let gap = theme.metrics.heatCellGap
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: 7)
        let first = DayKey(year: year, month: month, day: 1)
        let length = DayKey.daysInMonth(year: year, month: month)
        let blanks = HeatCalendar.leadingBlanks(firstDay: first, weekStart: weekStart)

        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(0..<7, id: \.self) { index in
                    Text(HeatCalendar.weekdayInitial((weekStart - 1 + index) % 7 + 1))
                        .font(theme.font(.caption))
                        .foregroundStyle(theme.palette.textSecondary)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(0..<blanks, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                ForEach(1...length, id: \.self) { number in
                    let day = first.adding(number - 1)
                    let step = heat[day]?.step ?? 0
                    SLHeatCell(
                        day: number,
                        state: day > today ? .future : .heat(step: step),
                        isToday: day == today
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        day > today
                            ? "\(HeatCalendar.monthName(month)) \(number), not yet"
                            : "\(HeatCalendar.monthName(month)) \(number), level \(step) of \(HeatCalculator.maxStep)"
                    )
                }
            }
        }
    }

    // MARK: Calendar words

    /// Blank grid positions before the first of the month.
    static func leadingBlanks(firstDay: DayKey, weekStart: Int) -> Int {
        (firstDay.weekday - weekStart + 7) % 7
    }

    static func monthName(_ month: Int) -> String {
        let names = symbols.monthSymbols
        return names.indices.contains(month - 1) ? names[month - 1] : ""
    }

    static func shortMonthName(_ month: Int) -> String {
        let names = symbols.shortMonthSymbols
        return names.indices.contains(month - 1) ? names[month - 1] : ""
    }

    /// `weekday` is 1 (Sunday) to 7.
    static func weekdayInitial(_ weekday: Int) -> String {
        let names = symbols.veryShortWeekdaySymbols
        return names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
    }

    static func weekdayName(_ weekday: Int) -> String {
        let names = symbols.weekdaySymbols
        return names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
    }

    static func shortWeekdayName(_ weekday: Int) -> String {
        let names = symbols.shortWeekdaySymbols
        return names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
    }
}
