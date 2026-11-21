import SwiftUI

/// How progress is drawn inside a surface (DESIGN.md 4.3 and 8.2).
///
/// Adding an effect means adding one case here and one renderer file beside
/// `SweepFill.swift`, then handling the case in `SLFill`.
nonisolated enum SLFillEffect: String, CaseIterable, Sendable {
    case sweep
    // Planned: water, fire, crumble, driven by physics and device tilt.
}

/// What a fill is saying, which decides its colours.
nonisolated enum SLFillTone: String, CaseIterable, Sendable {
    /// Ordinary progress.
    case progress
    /// A clear Avoid task: full but very faint.
    case faint
    /// A logged Avoid task: red-tinted.
    case alert
}

/// Progress drawn inside a surface. Views use this and never draw their own
/// fill.
///
/// - `fraction`: 0 to 1.
/// - `sections`: 2 to 4 divide the surface into equal panes with a seam
///   between them (DESIGN.md 9.2). Other values draw no seams.
/// - `phase`: 0 to 1, how far a hold in progress has advanced toward the
///   next step. Zero when nothing is being held.
struct SLFill: View {
    let effect: SLFillEffect
    let fraction: Double
    let sections: Int
    let phase: Double
    let tone: SLFillTone
    let cornerRadius: CGFloat?

    @Environment(\.slTheme) private var theme

    init(
        effect: SLFillEffect = .sweep,
        fraction: Double,
        sections: Int = 1,
        phase: Double = 0,
        tone: SLFillTone = .progress,
        cornerRadius: CGFloat? = nil
    ) {
        self.effect = effect
        self.fraction = fraction
        self.sections = sections
        self.phase = phase
        self.tone = tone
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let radius = cornerRadius ?? theme.metrics.cornerRadius(for: .card)
        Group {
            switch effect {
            case .sweep:
                SweepFill(fraction: fraction, sections: sections, phase: phase, tone: tone, theme: theme)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            if tone == .alert && fraction >= 1 {
                // A logged Avoid task has a red edge (DESIGN.md 7.2).
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.palette.alertEdge, lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
