import SwiftUI
import UIKit

/// The text styles in DESIGN.md 9.1. All use the system font.
nonisolated enum SLTextRole: String, CaseIterable, Sendable {
    /// Screen header, date and time: 19 semibold.
    case header
    /// Card title: 17 semibold. Shrinks to fit instead of following
    /// Dynamic Type (see `SLTypography.cardTitleMinimumScale`).
    case cardTitle
    /// Tracker title on Task details: 24 semibold.
    case trackerTitle
    /// Status on a card: 22 semibold.
    case status
    /// Large numbers (averages, streaks): 25 semibold.
    case largeNumber
    /// Body and row labels: 15 medium.
    case body
    /// Secondary text: 12 medium.
    case secondary
    /// Tab labels, weekday initials, axis labels: 11 medium.
    case caption
    /// The selected tab's label: 11 semibold.
    case captionStrong
}

/// Fonts for each text role.
///
/// Sizes are design-time points, scaled with the user's Dynamic Type setting
/// through `UIFontMetrics` (a plain `Font.system(size:)` is a fixed size).
/// UIKit is imported only for that. Scaling is capped so fixed-size chrome
/// such as the tab bar stays usable at accessibility sizes.
struct SLTypography: Equatable {
    var maxScale: CGFloat = 1.5
    /// Card titles shrink from 17 to 12 points to stay on one line.
    var cardTitleMinimumScale: CGFloat = 12.0 / 17.0

    static let standard = SLTypography()

    func size(for role: SLTextRole) -> CGFloat {
        switch role {
        case .header: return 19
        case .cardTitle: return 17
        case .trackerTitle: return 24
        case .status: return 22
        case .largeNumber: return 25
        case .body: return 15
        case .secondary: return 12
        case .caption, .captionStrong: return 11
        }
    }

    func weight(for role: SLTextRole) -> Font.Weight {
        switch role {
        case .header, .cardTitle, .trackerTitle, .status, .largeNumber, .captionStrong:
            return .semibold
        case .body, .secondary, .caption:
            return .medium
        }
    }

    func font(_ role: SLTextRole) -> Font {
        let base = size(for: role)
        // Card titles keep their design size and shrink to fit instead.
        let points = role == .cardTitle ? base : scaled(base)
        return .system(size: points, weight: weight(for: role))
    }

    func scaled(_ size: CGFloat) -> CGFloat {
        let metric = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        return min(metric, size * maxScale)
    }
}
