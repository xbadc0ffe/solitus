import SwiftUI

/// The floating pill tab bar (DESIGN.md 7.1). Content scrolls underneath it.
///
/// It is built from whatever sections it is given. Nothing here assumes
/// there are four tabs or that every tab belongs to Tasks (DESIGN.md 4.4).
struct SLTabBar: View {
    let sections: [AppSection]
    @Binding var selection: AppSection

    @Environment(\.slTheme) private var theme

    var body: some View {
        let metrics = theme.metrics
        HStack(spacing: 0) {
            ForEach(sections) { section in
                let isSelected = section == selection
                Button {
                    selection = section
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: section.symbol)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                            .frame(width: 22, height: 22)
                        Text(section.title)
                            .font(theme.font(isSelected ? .captionStrong : .caption))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? theme.palette.textPrimary : theme.palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.tabBarHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .frame(height: metrics.tabBarHeight)
        .background(SLSurface(role: .bar))
        .padding(.horizontal, metrics.screenMargin)
        .padding(.bottom, metrics.tabBarBottomInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }
}
