import SwiftUI

/// The flat style (DESIGN.md 9.1): a faint tinted gradient, a 1-point
/// border, a top inner highlight and one soft drop shadow. It ignores tilt.
///
/// Only the sheet and the tab bar blur what is behind them. The mockup also blurs behind
/// every other surface; that is left out until the look can be judged on a
/// device. With Reduce Transparency on, every surface is an opaque dark
/// panel and nothing is blurred (DESIGN.md 9.5).
struct FlatSurface: View {
    let role: SLSurfaceRole
    let cornerRadius: CGFloat
    let shape: SLCardShape
    let theme: SLTheme
    let tilt: SLTilt

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let palette = theme.palette
        let outline = self.outline

        ZStack {
            if castsShadow {
                // One soft drop shadow, pulled in so it only shows below.
                outline
                    .fill(palette.shadow)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .blur(radius: 9)
                    .offset(y: 10)
            }
            if reduceTransparency {
                outline.fill(palette.ground)
            } else if role == .sheet || role == .bar {
                // Content scrolls under the tab bar and sits behind a sheet.
                outline.fill(.ultraThinMaterial)
            }
            outline.fill(fill(palette))
            outline.strokeBorder(palette.surfaceBorder, lineWidth: 1)
            if hasHighlight {
                outline.strokeBorder(
                    LinearGradient(
                        colors: [palette.surfaceHighlight, palette.surfaceHighlight.opacity(0)],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.35)
                    ),
                    lineWidth: 1
                )
            }
        }
    }

    /// Sheets round only their top corners.
    private var outline: UnevenRoundedRectangle {
        let bottom = role == .sheet ? 0 : cornerRadius
        return UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    private var castsShadow: Bool {
        switch role {
        case .card, .panel, .statCard, .bar: return true
        case .row, .well, .sheet, .heatCell, .raised: return false
        }
    }

    private var hasHighlight: Bool {
        switch role {
        case .well, .heatCell: return false
        case .card, .panel, .statCard, .row, .bar, .sheet, .raised: return true
        }
    }

    private func fill(_ palette: SLPalette) -> LinearGradient {
        switch role {
        case .well:
            return LinearGradient(colors: [palette.well, palette.well], startPoint: .top, endPoint: .bottom)
        case .raised:
            return LinearGradient(colors: [palette.raisedTop, palette.raisedBottom], startPoint: .top, endPoint: .bottom)
        case .card, .panel, .statCard, .row, .bar, .sheet, .heatCell:
            // 160 degrees in the mockup: mostly downward, slightly rightward.
            return LinearGradient(
                colors: [palette.surfaceTop, palette.surfaceBottom],
                startPoint: UnitPoint(x: 0.33, y: 0),
                endPoint: UnitPoint(x: 0.67, y: 1)
            )
        }
    }
}
