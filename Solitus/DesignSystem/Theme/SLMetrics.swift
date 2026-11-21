import SwiftUI

/// Sizes, radii and spacing (DESIGN.md 9.1), in points on a 390-point-wide
/// phone.
struct SLMetrics: Equatable {
    // Spacing
    var screenMargin: CGFloat = 16
    var panelSpacing: CGFloat = 15
    var innerPadding: CGFloat = 14
    /// Every tappable control is at least this big in both directions.
    var minTapTarget: CGFloat = 44

    // Track grid
    var gridColumnGap: CGFloat = 12
    var gridRowGap: CGFloat = 16
    var cardHeight: CGFloat = 108
    /// Narrowest a Track card may be; decides the number of grid columns
    /// (two on a phone, more on wide screens).
    var cardMinWidth: CGFloat = 160
    /// Widest a scrolling page's content grows on a wide screen.
    var pageMaxWidth: CGFloat = 720
    var trackerCardHeight: CGFloat = 112
    var fillCardHeight: CGFloat = 58
    var statCardHeight: CGFloat = 72
    var yearTileHeight: CGFloat = 80
    var heatCellGap: CGFloat = 7
    var rowHeight: CGFloat = 56

    // Chrome
    var headerHeight: CGFloat = 44
    var tabBarHeight: CGFloat = 62
    var tabBarBottomInset: CGFloat = 18

    // Corner radii
    var cardRadius: CGFloat = 20
    var statCardRadius: CGFloat = 18
    var rowRadius: CGFloat = 16
    var wellRadius: CGFloat = 14
    var selectedSegmentRadius: CGFloat = 11
    var heatCellRadius: CGFloat = 7
    var yearTileRadius: CGFloat = 12
    var sheetRadius: CGFloat = 28

    static let standard = SLMetrics()

    /// The corner radius a surface role uses unless a view overrides it.
    func cornerRadius(for role: SLSurfaceRole) -> CGFloat {
        switch role {
        case .card, .panel: return cardRadius
        case .statCard: return statCardRadius
        case .row: return rowRadius
        case .well: return wellRadius
        case .raised: return selectedSegmentRadius
        case .bar: return tabBarHeight / 2
        case .sheet: return sheetRadius
        case .heatCell: return heatCellRadius
        }
    }
}
