import AppKit
import CoreGraphics

let inputPath = "/Users/baris/.gemini/antigravity/brain/5fbab6d4-93b4-4f66-ac11-25a38da93715/format_converter_app_icon_1791857342980.jpg"
guard let sourceImage = NSImage(contentsOfFile: inputPath),
      let tiffData = sourceImage.tiffRepresentation,
      let sourceRep = NSBitmapImageRep(data: tiffData),
      let sourceCGImage = sourceRep.cgImage else {
    print("Hata: Kaynak görsel yüklenemedi!")
    exit(1)
}

let canvasSize: CGFloat = 1024
let squircleInset: CGFloat = 120
let squircleSize: CGFloat = canvasSize - (squircleInset * 2) // 784x784
let cornerRadius = squircleSize * 0.224

func renderIcon(targetSize: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: targetSize, height: targetSize))
    img.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    ctx.interpolationQuality = .high

    let scale = targetSize / canvasSize
    let inset = squircleInset * scale
    let sSize = squircleSize * scale
    let cRadius = cornerRadius * scale

    let squircleRect = CGRect(x: inset, y: inset, width: sSize, height: sSize)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cRadius, cornerHeight: cRadius, transform: nil)

    // 1. macOS Dock için Yumuşak Doğal Gölge
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -14 * scale),
        blur: 24 * scale,
        color: NSColor.black.withAlphaComponent(0.40).cgColor
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Squircle Maskesi Uygulayarak Görseli Çiz
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Orijinal görseli çiz
    ctx.draw(sourceCGImage, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

    // İnce şık iç cam kontur (Frosted glass rim highlight)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.setLineWidth(1.5 * scale)
    ctx.addPath(squirclePath)
    ctx.strokePath()

    ctx.restoreGState()

    img.unlockFocus()
    return img
}

let fileManager = FileManager.default
let iconsetDir = "build/AppIcon.iconset"
try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, sz) in sizes {
    let img = renderIcon(targetSize: sz)
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let pngData = rep.representation(using: .png, properties: [:]) {
        let dest = "\(iconsetDir)/\(name)"
        try? pngData.write(to: URL(fileURLWithPath: dest))
    }
}

// 1024x1024 master PNG'yi Resources klasörüne de kaydet
let masterImg = renderIcon(targetSize: 1024)
if let tiff = masterImg.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let pngData = rep.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "Resources/AppIcon_1024.png"))
}

print("Format Çevirici AppIcon.iconset ve AppIcon_1024.png başarıyla oluşturuldu!")
