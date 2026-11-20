import Foundation
import SwiftData

/// Colour-scheme choice. Only `dark` has a theme today.
nonisolated enum AppearanceMode: String, CaseIterable, Sendable {
    case system, dark, light
}

/// The single stored settings record (DESIGN.md 5.4). Created on first launch
/// by `AppSettings.ensureExists(in:)`.
///
/// Enums are stored as raw strings. Every stored property has an inline
/// default so that properties added later migrate without a custom stage.
@Model
final class AppSettings {
    /// 1 (Sunday) to 7 (Saturday).
    var weekStart: Int = 1
    // OPEN: 12.5 the light theme is not designed, so the default is dark.
    var appearanceRaw: String = "dark"
    var surfaceStyleRaw: String = "flat"
    /// Has no visible effect while the style is `flat`.
    var effectsEnabled: Bool = true
    var glassTintHex: String = "#DCE6F5"
    var streakEmphasis: Bool = true
    var streakPriorityBoost: Bool = true
    var trendGroupSize: Int = 5
    var notificationsRequested: Bool = false

    init() {}

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .dark }
        set { appearanceRaw = newValue.rawValue }
    }

    var surfaceStyle: SLSurfaceStyle {
        get { SLSurfaceStyle(rawValue: surfaceStyleRaw) ?? .flat }
        set { surfaceStyleRaw = newValue.rawValue }
    }

    /// Returns the settings record, creating it if this is the first launch.
    @discardableResult
    static func ensureExists(in context: ModelContext) -> AppSettings {
        let existing = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        if let first = existing.first {
            return first
        }
        let settings = AppSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }
}
