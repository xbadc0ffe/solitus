import Foundation

/// An inclusive range of days: one day, one week or one calendar month.
nonisolated struct PeriodSpan: Hashable, Sendable {
    let start: DayKey
    let end: DayKey

    var dayCount: Int { start.days(until: end) + 1 }

    func contains(_ day: DayKey) -> Bool {
        day >= start && day <= end
    }

    /// Every day in the span, in order.
    var days: [DayKey] {
        (0..<dayCount).map { start.adding($0) }
    }
}

/// Period maths (DESIGN.md 6.1).
///
/// - Daily: one local calendar day.
/// - Weekly: seven days beginning on `weekStart`.
/// - Monthly: one calendar month.
nonisolated struct PeriodCalculator: Sendable {
    /// 1 (Sunday) to 7 (Saturday). Values outside that range are clamped.
    let weekStart: Int

    init(weekStart: Int = 1) {
        self.weekStart = min(max(weekStart, 1), 7)
    }

    func span(containing day: DayKey, period: TaskPeriod) -> PeriodSpan {
        switch period {
        case .daily:
            return PeriodSpan(start: day, end: day)
        case .weekly:
            let offset = (day.weekday - weekStart + 7) % 7
            let start = day.adding(-offset)
            return PeriodSpan(start: start, end: start.adding(6))
        case .monthly:
            let year = day.year
            let month = day.month
            let start = DayKey(year: year, month: month, day: 1)
            let length = DayKey.daysInMonth(year: year, month: month)
            return PeriodSpan(start: start, end: start.adding(length - 1))
        }
    }

    func next(after span: PeriodSpan, period: TaskPeriod) -> PeriodSpan {
        self.span(containing: span.end.adding(1), period: period)
    }

    func previous(before span: PeriodSpan, period: TaskPeriod) -> PeriodSpan {
        self.span(containing: span.start.adding(-1), period: period)
    }

    /// A period's count is the sum of its entries' counts.
    func count(in span: PeriodSpan, counts: DayCounts) -> Int {
        var total = 0
        var day = span.start
        while day <= span.end {
            total += counts[day] ?? 0
            day = day.adding(1)
        }
        return total
    }

    /// The count of the period that contains `day`.
    func count(containing day: DayKey, period: TaskPeriod, counts: DayCounts) -> Int {
        count(in: span(containing: day, period: period), counts: counts)
    }
}
