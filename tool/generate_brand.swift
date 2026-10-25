// Run on macOS: swift tool/generate_brand.swift
// One geometric key identity for Flutter, Apple icon catalogs and Android.
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func render(_ size: Int, mac: Bool = false) -> Data {
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (mac ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
    c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    if mac {
        let shape = NSBezierPath(roundedRect: NSRect(x: 84, y: 84, width: 856, height: 856), xRadius: 190, yRadius: 190)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        rgb(0x102A43).setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        shape.addClip()
    }
    let gradient = NSGradient(starting: rgb(0x0B141E), ending: rgb(0x21475C))!
    gradient.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: 60)
    if mac {
        c.translateBy(x: 84, y: 84)
        c.scaleBy(x: 0.836, y: 0.836)
    }
    // A circular bow and stepped diagonal blade, with generous optical padding.
    rgb(0x7EF0CF).setStroke()
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 456, y: 558))
    shaft.line(to: NSPoint(x: 716, y: 298))
    shaft.line(to: NSPoint(x: 654, y: 298))
    shaft.line(to: NSPoint(x: 654, y: 368))
    shaft.line(to: NSPoint(x: 584, y: 368))
    shaft.lineWidth = 64
    shaft.lineCapStyle = .round
    shaft.lineJoinStyle = .round
    shaft.stroke()
    let bow = NSBezierPath(ovalIn: NSRect(x: 258, y: 558, width: 236, height: 236))
    bow.lineWidth = 64
    bow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!
}
func write(_ data: Data, _ path: String) throws {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}
try write(render(1024), "assets/brand/keygen-mark.png")
for platform in ["ios", "macos"] {
    let catalog = "\(platform)/Runner/Assets.xcassets/AppIcon.appiconset/"
    let data = try Data(contentsOf: root.appendingPathComponent(catalog + "Contents.json"))
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    for entry in json["images"] as! [[String: Any]] {
        guard let file = entry["filename"] as? String else { continue }
        let points = Double((entry["size"] as! String).split(separator: "x")[0])!
        let scale = Double((entry["scale"] as! String).dropLast())!
        try write(render(Int(points * scale), mac: platform == "macos"), catalog + file)
    }
}
for (density, size) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
    try write(render(size), "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
for (suffix, size) in [("", 96), ("@2x", 192), ("@3x", 288)] {
    try write(render(size), "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage\(suffix).png")
}
print("Generated Keygen Client app icons and launch artwork.")
