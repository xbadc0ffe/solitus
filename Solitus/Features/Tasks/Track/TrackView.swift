import SwiftUI

/// The main screen (DESIGN.md 7.2). It answers one question: what is done,
/// and what is left?
///
/// Phase 0 shell: only the header exists. The card grid, the hold to fill,
/// the tap cycle and the ordering are phase 2.
struct TrackView: View {
    @Environment(\.slTheme) private var theme

    var body: some View {
        let metrics = theme.metrics
        ScrollView {
            VStack(spacing: metrics.panelSpacing) {
                header
                // Phase 2: the two-column grid of TaskCard, ordered by
                // PriorityRanker.
            }
            .padding(.horizontal, metrics.screenMargin)
            .padding(.top, 20)
            // Leave room for the floating tab bar.
            .padding(.bottom, metrics.tabBarHeight + metrics.tabBarBottomInset + metrics.panelSpacing)
        }
        .scrollIndicators(.hidden)
    }

    /// The date at top left and the live time at top right. No title.
    private var header: some View {
        TimelineView(.everyMinute) { timeline in
            HStack {
                Text(timeline.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                Spacer()
                Text(timeline.date.formatted(date: .omitted, time: .shortened))
            }
            .font(theme.font(.header))
            .foregroundStyle(theme.palette.textPrimary)
            .frame(height: theme.metrics.headerHeight)
            .padding(.horizontal, 4)
        }
    }
}
