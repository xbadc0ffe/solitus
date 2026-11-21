import SwiftUI

/// The year view of the heat calendar (DESIGN.md 7.3): twelve month tiles in
/// a 4-by-3 grid. Tapping a month opens it in the month view.
struct YearHeatView: View {
    let heat: [DayKey: HeatValue]
    let today: DayKey
    let weekStart: Int
    let year: Int
    let onSelect: (Int) -> Void

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...12, id: \.self) { month in
                let first = DayKey(year: year, month: month, day: 1)
                let length = DayKey.daysInMonth(year: year, month: month)
                Button {
                    onSelect(month)
                } label: {
                    SLYearTile(
                        title: HeatCalendar.shortMonthName(month),
                        leadingBlanks: HeatCalendar.leadingBlanks(firstDay: first, weekStart: weekStart),
                        heat: (0..<length).map { heat[first.adding($0)]?.heat },
                        isCurrent: year == today.year && month == today.month
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(HeatCalendar.monthName(month))
                .accessibilityHint("Opens the month")
            }
        }
    }
}
