import SwiftUI

/// The background of anything that looks like a surface.
///
/// Views ask `SLSurface(role:)` for their background. They never apply a
/// material, shadow or border themselves (DESIGN.md 4.3). The surface reads
/// the theme, the style and the motion tilt from the environment and hands
/// them to the renderer for the current style.
///
///     content.background(SLSurface(role: .card))
struct SLSurface: View {
    let role: SLSurfaceRole
    /// Overrides the role's corner radius from `SLMetrics`.
    let cornerRadius: CGFloat?
    let shape: SLCardShape

    @Environment(\.slTheme) private var theme
    @Environment(\.slSurfaceStyle) private var style
    @Environment(\.slTilt) private var tilt

    init(role: SLSurfaceRole, cornerRadius: CGFloat? = nil, shape: SLCardShape = .rectangle) {
        self.role = role
        self.cornerRadius = cornerRadius
        self.shape = shape
    }

    var body: some View {
        let radius = cornerRadius ?? theme.metrics.cornerRadius(for: role)
        switch style {
        case .flat:
            FlatSurface(role: role, cornerRadius: radius, shape: shape, theme: theme, tilt: tilt)
        }
    }
}
