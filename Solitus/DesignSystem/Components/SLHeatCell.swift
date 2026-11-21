import SwiftUI

/// One square, numbered day of the month view of the heat calendar
/// (DESIGN.md 7.3 and 9.3).
struct SLHeatCell: View {
    enum State: Equatable {
        /// A day up to today: its heat step, 0 to 5.
        case heat(step: Int)
        /// A day after today: an empty outline.
        case future
    }

    let day: Int
    let state: State
    let isToday: Bool

    @Environment(\.slTheme) private var theme

    var body: some View {
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: theme.metrics.heatCellRadius, style: .continuous)

        ZStack {
            switch state {
            case .heat(let step):
                let color = palette.heatColor(step: step)
                if step >= 2 {
                    // Hotter cells glow in their own colour.
                    shape.fill(color)
                        .blur(radius: CGFloat(step) * 1.6)
                        .opacity(0.25 + Double(step) * 0.1)
                }
                shape.fill(color)
                Text(String(day))
                    .foregroundStyle(palette.heatNumberColor(step: step))
            case .future:
                shape.strokeBorder(palette.futureOutline, lineWidth: 1)
                Text(String(day))
                    .foregroundStyle(palette.textFaint)
            }
            if isToday {
                shape.strokeBorder(palette.todayOutline, lineWidth: 1.5)
            }
        }
        .font(theme.font(.secondary))
        .aspectRatio(1, contentMode: .fit)
    }
}

/// One month of the year view (DESIGN.md 7.3): the month's short name and a
/// soft bloom of heat laid out where the month's days fall on a seven-column
/// grid. No cells and no numbers; the aim is a feel for the month.
struct SLYearTile: View {
    let title: String
    /// Blank positions before day 1, 0 to 6.
    let leadingBlanks: Int
    /// Heat `k(d)` for each day of the month, 0 to 1; nil where there is none.
    let heat: [Double?]
    let isCurrent: Bool

    @Environment(\.slTheme) private var theme

    var body: some View {
        let palette = theme.palette
        let metrics = theme.metrics
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(theme.font(.caption))
                .foregroundStyle(palette.textSecondary)
            Canvas { context, size in
                let columns = 7.0
                let rows = 6.0
                let cell = CGSize(width: size.width / columns, height: size.height / rows)
                context.addFilter(.blur(radius: min(cell.width, cell.height) * 0.45))
                for (index, value) in heat.enumerated() {
                    guard let value, value > 0.02 else { continue }
                    let position = index + leadingBlanks
                    let column = Double(position % 7)
                    let row = Double(position / 7)
                    let rect = CGRect(
                        x: column * cell.width,
                        y: row * cell.height,
                        width: cell.width,
                        height: cell.height
                    ).insetBy(dx: -cell.width * 0.2, dy: -cell.height * 0.2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(palette.heatColor(level: value).opacity(0.35 + 0.65 * value))
                    )
                }
            }
            .accessibilityHidden(true)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: metrics.yearTileHeight, maxHeight: metrics.yearTileHeight, alignment: .topLeading)
        .background(SLSurface(role: .well, cornerRadius: metrics.yearTileRadius))
        .clipShape(RoundedRectangle(cornerRadius: metrics.yearTileRadius, style: .continuous))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: metrics.yearTileRadius, style: .continuous)
                    .strokeBorder(palette.todayOutline.opacity(0.7), lineWidth: 1)
            }
        }
    }
}
