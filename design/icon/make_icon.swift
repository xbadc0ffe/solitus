// Draws the app icon: four glass squares in red, yellow, green and blue on
// the app's dark ground. The squares cover half of the icon's area.
//
//   swift design/icon/make_icon.swift Solitus/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let n: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(n), height: Int(n), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Work in a top-left origin so "top" means top.
ctx.translateBy(x: 0, y: n); ctx.scaleBy(x: 1, y: -1)

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}
func gradient(_ colors: [CGColor], _ stops: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: stops)!
}

// Four squares, each 362 on a side: 4 * 362 * 362 is 50% of 1024 * 1024.
let side: CGFloat = 362
let gap: CGFloat = 44
let origin = (n - (2 * side + gap)) / 2
let radius: CGFloat = 78
let depth: CGFloat = 20          // the slab's visible bottom edge

struct Tone { let r: CGFloat, g: CGFloat, b: CGFloat }
let tones = [
    Tone(r: 255, g: 59, b: 48),    // red, top left
    Tone(r: 255, g: 204, b: 0),    // yellow, top right
    Tone(r: 40, g: 205, b: 80),    // green, bottom left
    Tone(r: 20, g: 122, b: 255),   // blue, bottom right
]
func rect(_ i: Int) -> CGRect {
    CGRect(x: origin + CGFloat(i % 2) * (side + gap), y: origin + CGFloat(i / 2) * (side + gap) - depth / 2,
           width: side, height: side)
}
func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// Ground.
ctx.setFillColor(rgba(8, 9, 11)); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))

// Each square lights the ground around it.
for (i, t) in tones.enumerated() {
    let r = rect(i)
    let c = CGPoint(x: r.midX, y: r.midY)
    ctx.drawRadialGradient(gradient([rgba(t.r, t.g, t.b, 0.42), rgba(t.r, t.g, t.b, 0.13), rgba(t.r, t.g, t.b, 0)], [0, 0.55, 1]),
                           startCenter: c, startRadius: side * 0.30, endCenter: c, endRadius: side * 1.30, options: [])
}

for (i, t) in tones.enumerated() {
    let r = rect(i)
    let body = rounded(r, radius)

    // Cast shadow, down and to the right.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 10, height: -34), blur: 44, color: rgba(0, 0, 0, 0.60))
    ctx.addPath(rounded(r.offsetBy(dx: 0, dy: depth), radius)); ctx.setFillColor(rgba(0, 0, 0, 0.9)); ctx.fillPath()
    ctx.restoreGState()

    // The slab's thickness: a darker copy showing below the face.
    ctx.addPath(rounded(r.offsetBy(dx: 0, dy: depth), radius))
    ctx.setFillColor(rgba(t.r * 0.42, t.g * 0.42, t.b * 0.42)); ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(rounded(r.offsetBy(dx: 0, dy: depth), radius)); ctx.clip()
    ctx.drawLinearGradient(gradient([rgba(255, 255, 255, 0), rgba(255, 255, 255, 0.22)], [0, 1]),
                           start: CGPoint(x: 0, y: r.maxY - radius), end: CGPoint(x: 0, y: r.maxY + depth), options: [])
    ctx.restoreGState()

    // The face: lit glass, brighter toward the top left, glowing from inside.
    ctx.saveGState()
    ctx.addPath(body); ctx.clip()
    ctx.drawLinearGradient(gradient([rgba(min(t.r * 1.10 + 30, 255), min(t.g * 1.10 + 30, 255), min(t.b * 1.10 + 30, 255)),
                                     rgba(t.r, t.g, t.b), rgba(t.r * 0.66, t.g * 0.66, t.b * 0.66)], [0, 0.45, 1]),
                           start: CGPoint(x: r.minX, y: r.minY), end: CGPoint(x: r.maxX, y: r.maxY), options: [])
    let inner = CGPoint(x: r.midX + side * 0.06, y: r.midY + side * 0.10)
    ctx.drawRadialGradient(gradient([rgba(255, 255, 255, 0.30), rgba(255, 255, 255, 0)], [0, 1]),
                           startCenter: inner, startRadius: 0, endCenter: inner, endRadius: side * 0.52, options: [])
    // Reflection in the top-left corner.
    let glint = CGPoint(x: r.minX + side * 0.20, y: r.minY + side * 0.14)
    ctx.drawRadialGradient(gradient([rgba(255, 255, 255, 0.62), rgba(255, 255, 255, 0.16), rgba(255, 255, 255, 0)], [0, 0.45, 1]),
                           startCenter: glint, startRadius: 0, endCenter: glint, endRadius: side * 0.62, options: [])
    // A glossy sheen across the upper part of the face.
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: r.minX - side * 0.35, y: r.minY - side * 0.62, width: side * 1.7, height: side * 1.05)); ctx.clip()
    ctx.drawLinearGradient(gradient([rgba(255, 255, 255, 0.24), rgba(255, 255, 255, 0.03)], [0, 1]),
                           start: CGPoint(x: 0, y: r.minY), end: CGPoint(x: 0, y: r.minY + side * 0.45), options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    // Bevel: light on the top and left edges, dark on the bottom and right.
    ctx.saveGState()
    ctx.addPath(rounded(r.insetBy(dx: 3, dy: 3), radius - 3)); ctx.setLineWidth(6); ctx.replacePathWithStrokedPath(); ctx.clip()
    ctx.drawLinearGradient(gradient([rgba(255, 255, 255, 0.85), rgba(255, 255, 255, 0.10), rgba(0, 0, 0, 0.38)], [0, 0.5, 1]),
                           start: CGPoint(x: r.minX, y: r.minY), end: CGPoint(x: r.maxX, y: r.maxY), options: [])
    ctx.restoreGState()
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
