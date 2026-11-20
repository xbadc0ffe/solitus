import SwiftUI

/// Trends: a scrolling page about all tasks together (DESIGN.md 7.5).
///
/// Phase 0 shell: only the title exists. The screen is built in phase 5.
struct TrendsView: View {
    @Environment(\.slTheme) private var theme

    var body: some View {
        let metrics = theme.metrics
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.panelSpacing) {
                Text("Trends")
                    .font(theme.font(.header))
                    .foregroundStyle(theme.palette.textPrimary)
                    .frame(height: metrics.headerHeight)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, metrics.screenMargin)
            .padding(.top, 20)
            // Leave room for the floating tab bar.
            .padding(.bottom, metrics.tabBarHeight + metrics.tabBarBottomInset + metrics.panelSpacing)
        }
        .scrollIndicators(.hidden)
    }
}
