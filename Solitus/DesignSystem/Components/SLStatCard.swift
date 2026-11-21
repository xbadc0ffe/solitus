import SwiftUI

/// A number over a label (DESIGN.md 7.3): the streak cards and Top streaks.
struct SLStatCard: View {
    let value: String
    let label: String

    @Environment(\.slTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(theme.font(.largeNumber))
                .foregroundStyle(theme.palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(theme.font(.secondary))
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, theme.metrics.innerPadding)
        .frame(maxWidth: .infinity, minHeight: theme.metrics.statCardHeight, alignment: .leading)
        .background(SLSurface(role: .statCard))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// A card whose own background is a fill (DESIGN.md 7.3): the label on the
/// left, a value on the right, and behind them a gradient that brightens
/// toward the level and then fades out. There is no hard line and no bar.
///
/// `level` is where the fill ends, 0 to 1; `heat` is its place on the heat
/// ramp, `min(RA / fullAt, 1)` (DESIGN.md 6.5). Nil draws no fill.
struct SLFillCard: View {
    let label: String
    let value: String
    let level: Double?
    let heat: Double
    var compact = false

    @Environment(\.slTheme) private var theme

    var body: some View {
        let metrics = theme.metrics
        let radius = compact ? metrics.rowRadius : metrics.statCardRadius
        HStack {
            Text(label)
                .font(theme.font(.body))
                .foregroundStyle(theme.palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 8)
            Text(value)
                .font(theme.font(compact ? .body : .status))
                .foregroundStyle(theme.palette.textPrimary)
        }
        .padding(.horizontal, metrics.innerPadding)
        .frame(maxWidth: .infinity, minHeight: compact ? metrics.rowHeight - 8 : metrics.fillCardHeight)
        .background {
            ZStack {
                SLSurface(role: compact ? .row : .statCard)
                if let level, level > 0 {
                    fill(level: min(max(level, 0), 1))
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private func fill(level: Double) -> some View {
        let color = theme.palette.heatColor(level: max(heat, 0.25))
        let fade = min(level + 0.14, 1.0001)
        return LinearGradient(
            stops: [
                .init(color: color.opacity(0.10), location: 0),
                .init(color: color.opacity(0.80), location: level),
                .init(color: color.opacity(0), location: fade),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .allowsHitTesting(false)
    }
}

/// A small raised button in the app's style: "Undo last", "Add a task".
struct SLButton: View {
    enum Tone { case normal, destructive }

    let title: String
    var symbol: String?
    var tone: Tone = .normal
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SLButtonLabel(title: title, symbol: symbol, tone: tone, fillsWidth: fillsWidth)
        }
        .buttonStyle(.plain)
    }
}

/// The look of an `SLButton`, for controls that are not plain buttons
/// (a share link, a link to a web page).
struct SLButtonLabel: View {
    let title: String
    var symbol: String?
    var tone: SLButton.Tone = .normal
    var fillsWidth = false

    @Environment(\.slTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
            }
            Text(title).font(theme.font(.body)).lineLimit(1)
        }
        .foregroundStyle(tone == .destructive ? theme.palette.alertText : theme.palette.textPrimary)
        .padding(.horizontal, 16)
        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: theme.metrics.minTapTarget)
        .background(SLSurface(role: .raised, cornerRadius: theme.metrics.wellRadius))
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(Rectangle())
    }
}

/// A round colour swatch, for choosing the glass tint.
struct SLSwatch: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.slTheme) private var theme

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(slHexString: hex) ?? theme.palette.tint)
                .frame(width: 30, height: 30)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(theme.palette.ground, lineWidth: 3)
                        Circle().strokeBorder(theme.palette.textPrimary, lineWidth: 1.5).padding(-3)
                    }
                }
                .frame(width: theme.metrics.minTapTarget, height: theme.metrics.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
