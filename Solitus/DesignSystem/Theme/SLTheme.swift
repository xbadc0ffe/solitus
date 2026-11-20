import SwiftUI

/// The app's look as one value: colours, sizes and type (DESIGN.md 4.3).
/// Passed through the SwiftUI environment as `\.slTheme`.
///
/// `dynamicTypeSize` rides along so the value changes whenever the user's
/// text size does. Every view reads the theme, so the whole tree redraws and
/// `SLTypography` picks up the new scale.
struct SLTheme: Equatable {
    var palette: SLPalette
    var metrics: SLMetrics
    var typography: SLTypography
    var dynamicTypeSize: DynamicTypeSize

    init(
        palette: SLPalette,
        metrics: SLMetrics = .standard,
        typography: SLTypography = .standard,
        dynamicTypeSize: DynamicTypeSize = .large
    ) {
        self.palette = palette
        self.metrics = metrics
        self.typography = typography
        self.dynamicTypeSize = dynamicTypeSize
    }

    /// The dark neutral theme with the default glass tint.
    // OPEN: 12.5 there is no light theme; dark is the only one.
    static let dark = SLTheme(palette: .dark(tint: Color(slHex: 0xDCE6F5)))

    /// The dark theme with a user-chosen glass tint, given as a hex string
    /// such as `#DCE6F5`. An unreadable string falls back to the default.
    static func darkTinted(hex tintHex: String, dynamicTypeSize: DynamicTypeSize = .large) -> SLTheme {
        let tint = Color(slHexString: tintHex) ?? Color(slHex: 0xDCE6F5)
        return SLTheme(palette: .dark(tint: tint), dynamicTypeSize: dynamicTypeSize)
    }

    func font(_ role: SLTextRole) -> Font {
        typography.font(role)
    }
}

// MARK: Environment

private struct SLThemeKey: EnvironmentKey {
    static let defaultValue: SLTheme = .dark
}

private struct SLSurfaceStyleKey: EnvironmentKey {
    static let defaultValue: SLSurfaceStyle = .flat
}

private struct SLTiltKey: EnvironmentKey {
    static let defaultValue: SLTilt = .zero
}

extension EnvironmentValues {
    var slTheme: SLTheme {
        get { self[SLThemeKey.self] }
        set { self[SLThemeKey.self] = newValue }
    }

    var slSurfaceStyle: SLSurfaceStyle {
        get { self[SLSurfaceStyleKey.self] }
        set { self[SLSurfaceStyleKey.self] = newValue }
    }

    /// The current motion tilt, from the root view's `SLMotionProvider`.
    var slTilt: SLTilt {
        get { self[SLTiltKey.self] }
        set { self[SLTiltKey.self] = newValue }
    }
}

extension View {
    /// Sets the theme, surface style and motion tilt together.
    ///
    /// Sheets do not inherit custom environment values, so every sheet's
    /// content must call this with the presenting view's values
    /// (DESIGN.md 4.3). The root view calls it once for everything else.
    func slDesign(theme: SLTheme, surfaceStyle: SLSurfaceStyle, tilt: SLTilt) -> some View {
        self
            .environment(\.slTheme, theme)
            .environment(\.slSurfaceStyle, surfaceStyle)
            .environment(\.slTilt, tilt)
    }
}
