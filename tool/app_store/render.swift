// Native, reproducible marketing layout; no downloaded images or fonts.
import AppKit
import Foundation

let plan = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: Any]
let jobs = plan["jobs"] as! [[String: Any]]
let version = plan["edition"] as! String
let brand = plan["name"] as! String
let mark = NSImage(contentsOfFile: plan["mark"] as! String)!
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
for job in jobs {
    let width = job["width"] as! Int, height = job["height"] as! Int
    let w = CGFloat(width), h = CGFloat(height)
    let wide = w > h
    let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: x, y: h - y - height, width: width, height: height)
    }
    func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
              size: CGFloat, weight: NSFont.Weight = .regular, tint: NSColor = color(0xEAF1F7), spacing: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = size * 0.08
        NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: tint, .paragraphStyle: paragraph, .kern: spacing]).draw(in: rect(x, y, width, height))
    }
    NSGradient(colors: [color(0x09141F), color(0x163A42)])!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 50)
    // Restrained concentric lines echo the circular bow of the key emblem.
    color(0x7EF0CF, 0.07).setStroke()
    for factor in [CGFloat(0.55), 0.8, 1.05] {
        let diameter = w * factor
        let circle = NSBezierPath(ovalIn: rect(w * 0.74 - diameter / 2, h * 0.50 - diameter / 2, diameter, diameter))
        circle.lineWidth = 2
        circle.stroke()
    }
    let margin = w * (wide ? 0.055 : 0.067)
    let logoSize = w * (wide ? 0.038 : 0.058)
    let top = h * (wide ? 0.07 : 0.035)
    let logoRect = rect(margin, top, logoSize, logoSize)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: logoRect, xRadius: logoSize * 0.23, yRadius: logoSize * 0.23).addClip()
    mark.draw(in: logoRect)
    NSGraphicsContext.restoreGraphicsState()
    text(brand, x: margin + logoSize * 1.30, y: top + logoSize * 0.13,
         width: w * 0.65, height: logoSize, size: logoSize * 0.52, weight: .semibold)
    let mode = job["mode"] as! String
    let title = job["title"] as! String, subtitle = job["subtitle"] as! String
    let source = NSImage(contentsOfFile: job["source"] as! String)!
    let sourceSize = source.size
    var screenTop: CGFloat, maxScreenWidth: CGFloat, maxScreenHeight: CGFloat
    var screenX: CGFloat? = nil
    if wide && mode == "video" {
        text((job["label"] as! String), x: margin, y: h * 0.24, width: w * 0.31, height: h * 0.07,
             size: w * 0.011, weight: .semibold, tint: color(0x7EF0CF), spacing: 2)
        text(title, x: margin, y: h * 0.33, width: w * 0.31, height: h * 0.34,
             size: w * 0.037, weight: .bold, spacing: -1.5)
        text(subtitle, x: margin, y: h * 0.68, width: w * 0.29, height: h * 0.20,
             size: w * 0.016, tint: color(0xA9C0CD))
        screenTop = h * 0.20; maxScreenWidth = w * 0.57; maxScreenHeight = h * 0.70
        screenX = w * 0.40
    } else {
        let titleTop = h * (wide ? 0.18 : 0.12)
        text((job["label"] as! String), x: margin, y: titleTop - h * 0.035, width: w * 0.9, height: h * 0.04,
             size: w * (wide ? 0.012 : 0.020), weight: .semibold, tint: color(0x7EF0CF), spacing: 2.5)
        text(title, x: margin, y: titleTop, width: w * 0.87, height: h * (wide ? 0.14 : 0.105),
             size: w * (wide ? 0.044 : 0.073), weight: .bold, spacing: -2)
        text(subtitle, x: margin, y: titleTop + h * (wide ? 0.11 : 0.105), width: w * 0.85, height: h * 0.07,
             size: w * (wide ? 0.019 : 0.030), tint: color(0xA9C0CD))
        screenTop = h * (wide ? 0.40 : 0.32)
        maxScreenWidth = w * 0.86; maxScreenHeight = h * (wide ? 0.54 : 0.63)
    }
    let scale = min(maxScreenWidth / sourceSize.width, maxScreenHeight / sourceSize.height)
    let sw = sourceSize.width * scale, sh = sourceSize.height * scale
    let sx = screenX ?? ((w - sw) / 2)
    let screen = rect(sx, screenTop, sw, sh)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    shadow.shadowBlurRadius = w * 0.025; shadow.shadowOffset = NSSize(width: 0, height: -w * 0.012)
    shadow.set()
    color(0x142C3A).setFill()
    let frame = NSBezierPath(roundedRect: screen.insetBy(dx: -5, dy: -5), xRadius: w * 0.018, yRadius: w * 0.018)
    frame.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: w * 0.016, yRadius: w * 0.016).addClip()
    source.draw(in: screen, from: NSRect(origin: .zero, size: sourceSize), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    text("\(job["platform"] as! String)  ·  \(version)", x: margin, y: h * 0.968, width: w * 0.8,
         height: h * 0.025, size: w * (wide ? 0.010 : 0.018), tint: color(0x8FA8B6))
    NSGraphicsContext.restoreGraphicsState()
    let output = URL(fileURLWithPath: job["output"] as! String)
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!.write(to: output)
}
print("Rendered \(jobs.count) branded App Store marketing images.")
