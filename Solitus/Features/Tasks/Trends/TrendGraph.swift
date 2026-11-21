import Charts
import SwiftUI

/// The running-average graph (DESIGN.md 7.5).
///
/// The x-axis shows exactly one window (30 or 90 days) with today at the
/// right edge, and scrolls left through older history. The y-axis is fixed
/// at 0% to 100%. Lines differ in more than colour: Total is white and
/// thickest, Best is orange and solid, Worst is grey and dotted, and each
/// added task has its own colour and dash pattern.
struct TrendGraph: View {
    let lines: [TrendLine]
    let window: Int
    let today: DayKey
    let calendar: Calendar
    var height: CGFloat = 180

    @Environment(\.slTheme) private var theme

    private static let secondsPerDay: Double = 86_400

    private struct Sample: Identifiable {
        let id: Int
        let date: Date
        let value: Double
    }

    var body: some View {
        let palette = theme.palette
        let end = today.date(in: calendar, hour: 12) ?? Date()
        let start = today.adding(-(window - 1)).date(in: calendar, hour: 12) ?? end

        Chart {
            ForEach(lines) { line in
                ForEach(samples(line)) { sample in
                    LineMark(
                        x: .value("Day", sample.date),
                        y: .value("Average", sample.value),
                        series: .value("Line", line.id)
                    )
                    .foregroundStyle(TrendGraph.color(line.kind, palette))
                    .lineStyle(TrendGraph.stroke(line.kind))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.5, 1]) { value in
                AxisGridLine().foregroundStyle(palette.gridLine)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text("\(Int(number * 100))%")
                            .font(theme.font(.caption))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: window <= 30 ? 7 : 30)) { value in
                AxisGridLine().foregroundStyle(palette.gridLine)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(theme.font(.caption))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: Double(window - 1) * TrendGraph.secondsPerDay)
        .chartScrollPosition(initialX: start)
        .frame(height: height)
        // A new window needs a new scroll position.
        .id(window)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Running average over \(window) days")
        .accessibilityValue(TrendData.summary(lines))
    }

    private func samples(_ line: TrendLine) -> [Sample] {
        line.points.compactMap { point in
            guard let value = point.value, let date = point.day.date(in: calendar, hour: 12) else { return nil }
            return Sample(id: point.day.ordinal, date: date, value: value)
        }
    }

    // MARK: Line styles

    static func color(_ kind: TrendLine.Kind, _ palette: SLPalette) -> Color {
        switch kind {
        case .total: return palette.lineTotal
        case .best: return palette.lineBest
        case .worst: return palette.lineWorst
        case .task(let index):
            let extras = palette.lineExtras
            return extras.isEmpty ? palette.lineTotal : extras[index % extras.count]
        }
    }

    private static let taskDashes: [[CGFloat]] = [[7, 4], [2, 4], [9, 3, 2, 3], [1, 5], [12, 4]]

    static func stroke(_ kind: TrendLine.Kind) -> StrokeStyle {
        switch kind {
        case .total: return StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        case .best: return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        case .worst: return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [1, 5])
        case .task(let index):
            // The dash pattern steps on every fifth line so colour and dash
            // do not repeat together.
            let dash = taskDashes[(index + index / 4) % taskDashes.count]
            return StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round, dash: dash)
        }
    }
}

/// A short sample of a line's stroke, for legends.
struct TrendLineSample: View {
    let kind: TrendLine.Kind

    @Environment(\.slTheme) private var theme

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 1, y: 5))
            path.addLine(to: CGPoint(x: 25, y: 5))
        }
        .stroke(TrendGraph.color(kind, theme.palette), style: TrendGraph.stroke(kind))
        .frame(width: 26, height: 10)
        .accessibilityHidden(true)
    }
}

/// The small legend above the plot: each line's stroke, name and value.
struct TrendLegend: View {
    let lines: [TrendLine]

    @Environment(\.slTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(lines) { line in
                HStack(spacing: 5) {
                    TrendLineSample(kind: line.kind)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line.name)
                            .font(theme.font(.caption))
                            .foregroundStyle(theme.palette.textSecondary)
                        Text(CardStatusFormatter.percent(line.current))
                            .font(theme.font(.secondary).weight(.semibold))
                            .foregroundStyle(theme.palette.textPrimary)
                    }
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TrendData.summary(lines))
    }
}
