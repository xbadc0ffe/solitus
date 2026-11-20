import SwiftUI

/// The flat style (DESIGN.md 9.1): a faint tinted gradient, a 1-point
/// border, a top inner highlight and one soft drop shadow. It ignores tilt.
///
/// Unverified look: the mockup also blurs whatever is behind each surface.
/// That backdrop blur is left out until the look can be judged on a device.
struct FlatSurface: View {
    let role: SLSurfaceRole
    let cornerRadius: CGFloat
    let shape: SLCardShape
    let theme: SLTheme
    let tilt: SLTilt

    var body: some View {
        let palette = theme.palette
        let outline = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

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

    private var castsShadow: Bool {
        switch role {
        case .card, .panel, .statCard, .bar: return true
        case .row, .well, .sheet, .heatCell: return false
        }
    }

    private var hasHighlight: Bool {
        switch role {
        case .well, .heatCell: return false
        case .card, .panel, .statCard, .row, .bar, .sheet: return true
        }
    }

    private func fill(_ palette: SLPalette) -> LinearGradient {
        switch role {
        case .well:
            return LinearGradient(colors: [palette.well, palette.well], startPoint: .top, endPoint: .bottom)
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
