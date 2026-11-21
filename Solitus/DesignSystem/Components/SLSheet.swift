import SwiftUI

/// The one presentation every pop-up page shares (DESIGN.md 7.6).
///
/// - Slides up from the bottom over the current screen.
/// - Leaves about 64 points of the screen behind it visible at the top,
///   dimmed by a scrim.
/// - The sheet blurs what is behind it, has rounded top corners and a small
///   grabber. With Reduce Transparency on it is an opaque dark surface.
/// - Dismissed by dragging the grabber down or by tapping the strip above.
///
/// It is drawn inside the view that presents it, not by the system, so it
/// keeps that view's environment. It still sets the theme, surface style and
/// motion tilt on its content explicitly (DESIGN.md 4.3).
struct SLSheetHost<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    @ViewBuilder let sheetContent: (Item) -> SheetContent

    @Environment(\.slTheme) private var theme
    @Environment(\.slSurfaceStyle) private var surfaceStyle
    @Environment(\.slTilt) private var tilt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drag: CGFloat = 0

    /// The strip of the screen behind that stays visible above the sheet.
    static var topGap: CGFloat { 64 }
    private static var dismissDistance: CGFloat { 110 }

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                .accessibilityHidden(item != nil)

            if item != nil {
                theme.palette.sheetScrim
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .accessibilityLabel("Close")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let item {
                sheet(for: item)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .animation(.snappy(duration: 0.32), value: item?.id)
    }

    private func sheet(for item: Item) -> some View {
        VStack(spacing: 0) {
            // The grabber. Dragging it down dismisses the sheet.
            Capsule()
                .fill(theme.palette.textFaint)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity, minHeight: 26)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .global)
                        .onChanged { value in
                            drag = max(value.translation.height, 0)
                        }
                        .onEnded { value in
                            if value.translation.height > SLSheetHost.dismissDistance {
                                dismiss()
                            }
                            withAnimation(.snappy(duration: 0.25)) {
                                drag = 0
                            }
                        }
                )
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { dismiss() }

            sheetContent(item)
                .slDesign(theme: theme, surfaceStyle: surfaceStyle, tilt: tilt)
        }
        .frame(maxWidth: 640)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SLSurface(role: .sheet).ignoresSafeArea(edges: .bottom))
        .padding(.top, SLSheetHost.topGap)
        .offset(y: drag)
    }

    private func dismiss() {
        item = nil
    }
}

extension View {
    /// Presents an `SLSheet` over this view while `item` is set.
    func slSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(SLSheetHost(item: item, sheetContent: content))
    }
}

/// The bar at the top of a sheet: an action on each side of a title.
struct SLSheetBar: View {
    let title: String
    let leading: String
    let trailing: String?
    var trailingEnabled = true
    let onLeading: () -> Void
    var onTrailing: () -> Void = {}

    @Environment(\.slTheme) private var theme

    var body: some View {
        let palette = theme.palette
        ZStack {
            Text(title)
                .font(theme.font(.body).weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(leading, action: onLeading)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                if let trailing {
                    Button(trailing, action: onTrailing)
                        .fontWeight(.semibold)
                        .foregroundStyle(trailingEnabled ? palette.textPrimary : palette.textFaint)
                        .disabled(!trailingEnabled)
                }
            }
            .buttonStyle(.plain)
            .font(theme.font(.body))
        }
        .frame(minHeight: theme.metrics.minTapTarget)
        .padding(.horizontal, theme.metrics.screenMargin)
    }
}
