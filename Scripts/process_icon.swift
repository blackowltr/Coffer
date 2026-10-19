import AppKit
import CoreGraphics

let projectDir = FileManager.default.currentDirectoryPath
let inputPath = "\(projectDir)/Resources/OriginalUserLogo.jpg"
guard let sourceImage = NSImage(contentsOfFile: inputPath),
      let tiffData = sourceImage.tiffRepresentation,
      let sourceRep = NSBitmapImageRep(data: tiffData),
      let sourceCG = sourceRep.cgImage else {
    print("Hata: Kaynak görsel bulunamadı: \(inputPath)")
    exit(1)
}

let canvasSize: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()

func renderIcon(targetSize: CGFloat) -> NSImage {
    let w = Int(targetSize)
    let h = Int(targetSize)
    let scale = targetSize / canvasSize

    guard let ctx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return NSImage(size: NSSize(width: targetSize, height: targetSize))
    }

    ctx.interpolationQuality = .high

    let squircleWidth: CGFloat = 824 * scale
    let squircleHeight: CGFloat = 824 * scale
    let originX: CGFloat = (targetSize - squircleWidth) / 2.0
    let originY: CGFloat = (targetSize - squircleHeight) / 2.0 + (6 * scale)
    let cRadius: CGFloat = 185 * scale

    let squircleRect = CGRect(x: originX, y: originY, width: squircleWidth, height: squircleHeight)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cRadius, cornerHeight: cRadius, transform: nil)

    // 1. Apple macOS Dock Yumuşak Derin Gölgesi
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -14 * scale),
        blur: 20 * scale,
        color: CGColor(red: 0.12, green: 0.18, blue: 0.35, alpha: 0.28)
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Doğrudan düşen gölge
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -4 * scale),
        blur: 8 * scale,
        color: CGColor(red: 0.08, green: 0.12, blue: 0.25, alpha: 0.20)
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // 3. Squircle İçine Maskeleme ve Çizim
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let srcSquircleRect = CGRect(x: 114, y: 104, width: 802, height: 832)
    let drawScaleX = squircleWidth / srcSquircleRect.width
    let drawScaleY = squircleHeight / srcSquircleRect.height
    let drawW = canvasSize * drawScaleX
    let drawH = canvasSize * drawScaleY
    let drawX = originX - (srcSquircleRect.origin.x * drawScaleX)
    let drawY = originY - (srcSquircleRect.origin.y * drawScaleY)

    ctx.draw(sourceCG, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))

    // 4. İnce metalik / cam iç kontur
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.40))
    ctx.setLineWidth(1.5 * scale)
    ctx.addPath(squirclePath)
    ctx.strokePath()

    ctx.restoreGState()

    guard let cgImage = ctx.makeImage() else {
        return NSImage(size: NSSize(width: targetSize, height: targetSize))
    }
    return NSImage(cgImage: cgImage, size: NSSize(width: targetSize, height: targetSize))
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

print("AppIcon.iconset yeni logoyla başarıyla oluşturuldu!")
