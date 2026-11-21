import Foundation

/// The look of every surface in the app (DESIGN.md 4.3).
///
/// Adding a style means adding one case here and one renderer file beside
/// `FlatSurface.swift`, then handling the case in `SLSurface`. Stored in
/// `AppSettings` as its raw string.
nonisolated enum SLSurfaceStyle: String, CaseIterable, Sendable {
    case flat
    // Planned: glass3D, then wood, leaves and others.
}

/// What a surface is for. The style decides how each role is drawn.
nonisolated enum SLSurfaceRole: String, CaseIterable, Sendable {
    case card, panel, statCard, row, well, bar, sheet, heatCell
    /// A raised control: a selected segment, a stepper button, a chip.
    case raised
}

/// The outline of a card. A parameter from the start so circles and other
/// shapes can be added later.
nonisolated enum SLCardShape: String, CaseIterable, Sendable {
    case rectangle
}
