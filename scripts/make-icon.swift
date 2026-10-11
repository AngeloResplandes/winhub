// Draws WinHub's app icon (four white panes turning around a center, on black) and writes
// an .icns, or an .svg for documentation. Usage: swift scripts/make-icon.swift <output.icns|output.svg>
//
// The icon is drawn from code so no image binaries live in the repository.
// Geometry follows Apple's 1024 pt icon grid: an 824 pt body with continuous corners.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

let canvas: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)

/// The panes, in 1024 pt top-left canvas coordinates, with the larger radius on their outer corner.
let panes: [(CGRect, RectangleCornerRadii)] = {
    let long: CGFloat = 233.6, short: CGFloat = 169.6, outer: CGFloat = 48, inner: CGFloat = 16
    return [
        (CGRect(x: 299.2, y: 299.2, width: long, height: short),
         RectangleCornerRadii(topLeading: outer, bottomLeading: inner, bottomTrailing: inner, topTrailing: inner)),
        (CGRect(x: 555.2, y: 299.2, width: short, height: long),
         RectangleCornerRadii(topLeading: inner, bottomLeading: inner, bottomTrailing: inner, topTrailing: outer)),
        (CGRect(x: 491.2, y: 555.2, width: long, height: short),
         RectangleCornerRadii(topLeading: inner, bottomLeading: inner, bottomTrailing: outer, topTrailing: inner)),
        (CGRect(x: 299.2, y: 491.2, width: short, height: long),
         RectangleCornerRadii(topLeading: inner, bottomLeading: outer, bottomTrailing: inner, topTrailing: inner)),
    ]
}()

let bodyPath = RoundedRectangle(cornerRadius: 185.6, style: .continuous).path(in: body).cgPath
/// Hairline so the black body still reads on a dark Dock.
let hairlinePath = RoundedRectangle(cornerRadius: 184.8, style: .continuous).path(in: body.insetBy(dx: 0.8, dy: 0.8)).cgPath
let panePaths = panes.map { UnevenRoundedRectangle(cornerRadii: $1, style: .continuous).path(in: $0).cgPath }

func render(pixels: Int) -> CGImage {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / canvas
    // Top-left origin, like the design.
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: scale, y: -scale)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -16 * scale), blur: 40 * scale,
                      color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(bodyPath)
    context.setFillColor(CGColor(srgbRed: 0.055, green: 0.055, blue: 0.055, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.addPath(hairlinePath)
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
    context.setLineWidth(1.6)
    context.strokePath()

    context.setFillColor(CGColor(gray: 1, alpha: 1))
    for path in panePaths { context.addPath(path) }
    context.fillPath()
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
}

/// The same drawing as SVG path data (top-left coordinates, like the bitmap).
func svgData(_ path: CGPath) -> String {
    var parts: [String] = []
    let n = { (p: CGPoint) in String(format: "%.2f %.2f", p.x, p.y) }
    path.applyWithBlock { element in
        let points = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: parts.append("M" + n(points[0]))
        case .addLineToPoint: parts.append("L" + n(points[0]))
        case .addQuadCurveToPoint: parts.append("Q" + n(points[0]) + " " + n(points[1]))
        case .addCurveToPoint: parts.append("C" + n(points[0]) + " " + n(points[1]) + " " + n(points[2]))
        case .closeSubpath: parts.append("Z")
        @unknown default: break
        }
    }
    return parts.joined()
}

func svg() -> String {
    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="Ícone do WinHub">
      <defs><filter id="shadow" x="-10%" y="-10%" width="120%" height="125%">\
    <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#000" flood-opacity="0.3"/></filter></defs>
      <path d="\(svgData(bodyPath))" fill="#0E0E0E" filter="url(#shadow)"/>
      <path d="\(svgData(hairlinePath))" fill="none" stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="1.6"/>
      <path d="\(panePaths.map(svgData).joined())" fill="#FFFFFF"/>
    </svg>

    """
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-icon.swift <output.icns|output.svg>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
if output.pathExtension == "svg" {
    try svg().write(to: output, atomically: true, encoding: .utf8)
    exit(0)
}
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    writePNG(render(pixels: points), to: iconset.appending(path: "icon_\(points)x\(points).png"))
    writePNG(render(pixels: points * 2), to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
