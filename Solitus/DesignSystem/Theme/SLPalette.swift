import Foundation
import SwiftUI

/// Every colour the app uses (DESIGN.md 9.1 and 9.3). Views read colours
/// only from here, through `SLTheme`.
///
/// Most surface colours are the glass tint at some opacity, so the palette
/// is built from a tint rather than listing each one.
struct SLPalette: Equatable {
    /// The glass tint that surfaces, fills and raised controls derive from.
    let tint: Color

    // Ground and text
    let ground: Color
    let textPrimary: Color
    let textSecondary: Color
    let textFaint: Color

    // Surfaces
    let surfaceTop: Color
    let surfaceBottom: Color
    let surfaceBorder: Color
    let surfaceHighlight: Color
    let shadow: Color
    let well: Color
    let raisedTop: Color
    let raisedBottom: Color

    // Fills
    let fillTop: Color
    let fillBottom: Color
    let fillEdge: Color
    let faintFillTop: Color
    let faintFillBottom: Color
    let alertFillTop: Color
    let alertFillBottom: Color
    let alertEdge: Color

    // Seams
    let seamDark: Color
    let seamLight: Color
    let seamGlow: Color

    // Sheets
    let sheetScrim: Color

    // Background light
    let backgroundFieldA: Color
    let backgroundFieldB: Color
    let backgroundFieldC: Color
    let backgroundBand: Color

    /// The heat ramp, steps 0 to 5 (DESIGN.md 9.3). Black to bright orange.
    let heatRamp: [Color]
    /// The colour of a number drawn on each heat step.
    let heatNumber: [Color]
}

extension SLPalette {
    static let defaultTintHex = "#DCE6F5"

    /// The dark neutral palette, built around a glass tint.
    static func dark(tint: Color) -> SLPalette {
        let white = Color.white
        let black = Color.black
        let alert = Color(red: 226 / 255, green: 92 / 255, blue: 72 / 255)
        let lightNumber = Color(slHex: 0xF2F3F5)
        let darkNumber = Color(slHex: 0x1A0E05)

        return SLPalette(
            tint: tint,
            ground: Color(slHex: 0x08090B),
            textPrimary: white,
            textSecondary: white.opacity(0.74),
            textFaint: white.opacity(0.62),
            surfaceTop: tint.opacity(0.11),
            surfaceBottom: tint.opacity(0.03),
            surfaceBorder: white.opacity(0.12),
            surfaceHighlight: white.opacity(0.18),
            shadow: black.opacity(0.75),
            well: black.opacity(0.30),
            raisedTop: tint.opacity(0.30),
            raisedBottom: tint.opacity(0.14),
            fillTop: tint.opacity(0.24),
            fillBottom: tint.opacity(0.11),
            fillEdge: white.opacity(0.16),
            faintFillTop: tint.opacity(0.10),
            faintFillBottom: tint.opacity(0.04),
            alertFillTop: alert.opacity(0.34),
            alertFillBottom: alert.opacity(0.16),
            alertEdge: Color(red: 240 / 255, green: 128 / 255, blue: 108 / 255).opacity(0.65),
            seamDark: black.opacity(0.50),
            seamLight: white.opacity(0.36),
            seamGlow: white.opacity(0.08),
            sheetScrim: black.opacity(0.50),
            backgroundFieldA: Color(red: 140 / 255, green: 158 / 255, blue: 190 / 255).opacity(0.30),
            backgroundFieldB: Color(red: 150 / 255, green: 152 / 255, blue: 172 / 255).opacity(0.16),
            backgroundFieldC: Color(red: 112 / 255, green: 132 / 255, blue: 162 / 255).opacity(0.20),
            backgroundBand: white.opacity(0.07),
            heatRamp: [
                Color(red: 12 / 255, green: 12 / 255, blue: 14 / 255),
                Color(red: 44 / 255, green: 22 / 255, blue: 6 / 255),
                Color(red: 96 / 255, green: 44 / 255, blue: 8 / 255),
                Color(red: 150 / 255, green: 70 / 255, blue: 8 / 255),
                Color(red: 232 / 255, green: 120 / 255, blue: 16 / 255),
                Color(red: 255 / 255, green: 164 / 255, blue: 44 / 255),
            ],
            heatNumber: [lightNumber, lightNumber, lightNumber, lightNumber, darkNumber, darkNumber]
        )
    }

    /// The heat colour for a step from 0 to 5. Out-of-range steps clamp.
    func heatColor(step: Int) -> Color {
        guard let last = heatRamp.indices.last else { return ground }
        return heatRamp[min(max(step, 0), last)]
    }

    /// The colour of a number drawn on a heat step.
    func heatNumberColor(step: Int) -> Color {
        guard let last = heatNumber.indices.last else { return textPrimary }
        return heatNumber[min(max(step, 0), last)]
    }
}

extension Color {
    /// A colour from a 24-bit RGB value such as `0x08090B`.
    init(slHex hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    /// A colour from a string such as `#DCE6F5` or `DCE6F5`. Returns nil if
    /// the string is not six hex digits.
    init?(slHexString string: String) {
        var digits = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(slHex: value)
    }
}
