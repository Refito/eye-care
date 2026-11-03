import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = output.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let factor = CGFloat(pixels) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: factor)
        transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 215, yRadius: 215)
        NSGradient(starting: NSColor(white: 0.04, alpha: 1), ending: NSColor(white: 0.30, alpha: 1))!
            .draw(in: tile, angle: 60)
        NSColor.white.setStroke()
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: 209, y: 512))
        eye.curve(to: NSPoint(x: 815, y: 512), controlPoint1: NSPoint(x: 367, y: 756), controlPoint2: NSPoint(x: 657, y: 756))
        eye.curve(to: NSPoint(x: 209, y: 512), controlPoint1: NSPoint(x: 657, y: 268), controlPoint2: NSPoint(x: 367, y: 268))
        eye.lineWidth = 43
        eye.lineJoinStyle = .round
        eye.close()
        eye.stroke()
        let iris = NSBezierPath(ovalIn: NSRect(x: 416, y: 416, width: 192, height: 192))
        iris.lineWidth = 38
        iris.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
// ICNS supports PNG payloads; write the container directly without an image-conversion service.
func lengthBytes(_ count: Int) -> Data {
    var length = UInt32(count).bigEndian
    return withUnsafeBytes(of: &length) { Data($0) }
}
let entries = [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"), ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"), ("ic12", "icon_32x32@2x.png"),
    ("ic13", "icon_128x128@2x.png"), ("ic14", "icon_256x256@2x.png")
]
var payload = Data()
for (type, filename) in entries {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    payload.append(Data(type.utf8))
    payload.append(lengthBytes(png.count + 8))
    payload.append(png)
}
var icon = Data("icns".utf8)
icon.append(lengthBytes(payload.count + 8))
icon.append(payload)
try icon.write(to: output.appendingPathComponent("AppIcon.icns"))
try FileManager.default.removeItem(at: iconset)
