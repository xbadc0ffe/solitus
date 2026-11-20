import SwiftUI

/// The `sweep` fill effect: the fill grows from the left edge to `fraction`
/// of the width (DESIGN.md 7.2). While a hold is in progress, `phase` moves
/// the edge toward the next step (DESIGN.md 8.2).
///
/// This file only draws. The hold gesture, its easing, the "pop" and the
/// haptic belong to the Track card and are built in phase 2.
struct SweepFill: View {
    /// Total hold time in seconds. A v1 proposal; tune on the device.
    static let holdDuration = 0.6
    /// Seams are drawn only for this range of section counts.
    static let seamSections = 2...4
    private static let seamWidth: CGFloat = 12

    let fraction: Double
    let sections: Int
    let phase: Double
    let tone: SLFillTone
    let theme: SLTheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let shown = SweepFill.shownFraction(fraction: fraction, sections: sections, phase: phase)
            let fillWidth = width * shown
            let isPartial = shown > 0 && shown < 1

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LinearGradient(colors: fillColors, startPoint: .top, endPoint: .bottom))
                    .frame(width: fillWidth)

                if isPartial {
                    // The edge of a partial fill is a faint line.
                    Rectangle()
                        .fill(theme.palette.fillEdge)
                        .frame(width: 1)
                        .offset(x: max(fillWidth - 1, 0))
                }

                if SweepFill.seamSections.contains(sections) {
                    ForEach(1..<sections, id: \.self) { index in
                        seam.offset(x: width * CGFloat(index) / CGFloat(sections) - SweepFill.seamWidth / 2)
                    }
                }
            }
            .frame(width: width, height: proxy.size.height, alignment: .leading)
        }
    }

    /// The fraction on screen: the saved fraction plus the part of the next
    /// step that the current hold has covered.
    static func shownFraction(fraction: Double, sections: Int, phase: Double) -> Double {
        let base = min(max(fraction, 0), 1)
        let step = sections > 0 ? 1 / Double(sections) : 1
        let held = min(max(phase, 0), 1) * step
        return min(base + held, 1)
    }

    private var fillColors: [Color] {
        let palette = theme.palette
        switch tone {
        case .progress: return [palette.fillTop, palette.fillBottom]
        case .faint: return [palette.faintFillTop, palette.faintFillBottom]
        case .alert: return [palette.alertFillTop, palette.alertFillBottom]
        }
    }

    /// A seam (DESIGN.md 9.2): a 1-point dark line beside a 1-point light
    /// line, with a faint glow fading out a few points to either side. It
    /// should read as a join between panes of glass, not as a divider drawn
    /// on top.
    private var seam: some View {
        let palette = theme.palette
        return HStack(spacing: 0) {
            LinearGradient(
                colors: [palette.seamGlow.opacity(0), palette.seamGlow],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 5)
            Rectangle().fill(palette.seamDark).frame(width: 1)
            Rectangle().fill(palette.seamLight).frame(width: 1)
            LinearGradient(
                colors: [palette.seamGlow, palette.seamGlow.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 5)
        }
        .frame(width: SweepFill.seamWidth)
    }
}
