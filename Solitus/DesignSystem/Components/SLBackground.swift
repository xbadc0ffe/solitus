import SwiftUI

/// The ground behind every screen (DESIGN.md 9.1).
///
/// The ground is not flat black. A few very soft, large, neutral light
/// fields and two faint diagonal bands of light sit behind everything, so
/// that translucent surfaces have something to show through. Positions and
/// sizes come from the mockups, on a 390 by 844 canvas, and are scaled to
/// the actual screen.
struct SLBackground: View {
    @Environment(\.slTheme) private var theme

    private static let designWidth: CGFloat = 390
    private static let designHeight: CGFloat = 844

    var body: some View {
        let palette = theme.palette
        GeometryReader { proxy in
            let sx = proxy.size.width / SLBackground.designWidth
            let sy = proxy.size.height / SLBackground.designHeight

            ZStack(alignment: .topLeading) {
                palette.ground

                field(palette.backgroundFieldA, diameter: 520 * sx)
                    .offset(x: -160 * sx, y: -140 * sy)
                field(palette.backgroundFieldB, diameter: 460 * sx)
                    .offset(x: 120 * sx, y: 300 * sy)
                field(palette.backgroundFieldC, diameter: 480 * sx)
                    .offset(x: -180 * sx, y: 560 * sy)

                band(palette.backgroundBand, width: 620 * sx, height: 46)
                    .offset(x: -80 * sx, y: 190 * sy)
                band(palette.backgroundBand.opacity(0.7), width: 680 * sx, height: 70)
                    .offset(x: -120 * sx, y: 520 * sy)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// A soft round light that fades to nothing two thirds of the way out.
    private func field(_ color: Color, diameter: CGFloat) -> some View {
        RadialGradient(
            colors: [color, color.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: diameter / 2 * 0.66
        )
        .frame(width: diameter, height: diameter)
    }

    /// A faint diagonal streak, brightest along its middle.
    private func band(_ color: Color, width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [color.opacity(0), color, color.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
        .rotationEffect(.degrees(-24))
    }
}
