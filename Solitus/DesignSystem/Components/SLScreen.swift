import SwiftUI

/// The frame every scrolling page shares: the background, the screen
/// margins, room for the floating tab bar, and a width limit so pages do
/// not stretch across a wide screen.
struct SLScreen<Content: View>: View {
    /// Nil lets the content use the full width (the Track grid does).
    let maxWidth: CGFloat?
    let content: Content

    @Environment(\.slTheme) private var theme

    init(maxWidth: CGFloat? = SLMetrics.standard.pageMaxWidth, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        let metrics = theme.metrics
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.panelSpacing) {
                content
            }
            .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, metrics.screenMargin)
            .padding(.top, 20)
            // Leave room for the floating tab bar.
            .padding(.bottom, metrics.tabBarHeight + metrics.tabBarBottomInset + metrics.panelSpacing)
        }
        .scrollIndicators(.hidden)
        .background(SLBackground())
    }
}

/// A page title in the header style ("Trends", "Tasks", "Settings").
struct SLScreenTitle: View {
    let text: String

    @Environment(\.slTheme) private var theme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(theme.font(.header))
            .foregroundStyle(theme.palette.textPrimary)
            .frame(height: theme.metrics.headerHeight)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
