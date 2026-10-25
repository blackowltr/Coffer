import AppKit
import CoreGraphics

let fileManager = FileManager.default
let projectDir = fileManager.currentDirectoryPath
let buildDir = "\(projectDir)/build"
let masterIconPath = "\(projectDir)/Resources/AppIcon_1024.png"

let masterAppImage = NSImage(contentsOfFile: masterIconPath)

struct DocIconConfig {
    let name: String
    let label: String
    let sublabel: String
    let primaryColor: NSColor      // Derin taban rengi
    let secondaryColor: NSColor    // Canlı sıvı neon rengi
    let highlightColor: NSColor    // Üst cam parıltı rengi
    let accentSymbol: String
}

let configs: [DocIconConfig] = [
    DocIconConfig(
        name: "RarDocIcon",
        label: "RAR",
        sublabel: "WINRAR ARCHIVE",
        primaryColor: NSColor(red: 0.38, green: 0.08, blue: 0.68, alpha: 1.0),   // Royal Amethyst
        secondaryColor: NSColor(red: 0.65, green: 0.18, blue: 0.98, alpha: 1.0), // Neon Orchid
        highlightColor: NSColor(red: 0.92, green: 0.45, blue: 1.0, alpha: 1.0),  // Liquid Magenta Glare
        accentSymbol: "books.vertical.fill"
    ),
    DocIconConfig(
        name: "ZipDocIcon",
        label: "ZIP",
        sublabel: "APPLE ZIP ARCHIVE",
        primaryColor: NSColor(red: 0.02, green: 0.28, blue: 0.78, alpha: 1.0),   // Deep Ocean Azure
        secondaryColor: NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0),  // Electric Azure
        highlightColor: NSColor(red: 0.42, green: 0.82, blue: 1.0, alpha: 1.0),  // Sky Cyan Glare
        accentSymbol: "doc.zipper"
    ),
    DocIconConfig(
        name: "SevenZipDocIcon",
        label: "7Z",
        sublabel: "7-ZIP ARCHIVE",
        primaryColor: NSColor(red: 0.02, green: 0.42, blue: 0.28, alpha: 1.0),   // Deep Emerald
        secondaryColor: NSColor(red: 0.05, green: 0.68, blue: 0.44, alpha: 1.0), // Vivid Apple Mint
        highlightColor: NSColor(red: 0.38, green: 0.92, blue: 0.68, alpha: 1.0), // Neon Mint Glare
        accentSymbol: "archivebox.fill"
    ),
    DocIconConfig(
        name: "TarDocIcon",
        label: "TAR.GZ",
        sublabel: "TAR GZIP ARCHIVE",
        primaryColor: NSColor(red: 0.22, green: 0.28, blue: 0.42, alpha: 1.0),   // Deep Cobalt Slate
        secondaryColor: NSColor(red: 0.38, green: 0.48, blue: 0.68, alpha: 1.0), // Electric Steel
        highlightColor: NSColor(red: 0.65, green: 0.75, blue: 0.95, alpha: 1.0),  // Platinum Cyan Glare
        accentSymbol: "shippingbox.fill"
    ),
    DocIconConfig(
        name: "ArchiveDocIcon",
        label: "ARCHIVE",
        sublabel: "COMPRESSED FILE",
        primaryColor: NSColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1.0),   // Deep Obsidian
        secondaryColor: NSColor(red: 0.32, green: 0.36, blue: 0.45, alpha: 1.0), // Titanium Glass
        highlightColor: NSColor(red: 0.68, green: 0.72, blue: 0.82, alpha: 1.0), // Platinum Glare
        accentSymbol: "lock.shield.fill"
    )
]

let iconSizes: [(String, CGFloat)] = [
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

// MARK: - Yüksek Çözünürlüklü Apple Liquid Glass Belge Simgesi (128px - 1024px)

func drawLargeDocumentIcon(config: DocIconConfig, canvasSize: CGFloat = 1024) -> NSImage {
    let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.interpolationQuality = .high

    let docW: CGFloat = 726
    let docH: CGFloat = 896
    let docX: CGFloat = (canvasSize - docW) / 2
    let docY: CGFloat = 58
    let foldSize: CGFloat = 182
    let cornerRadius: CGFloat = 42

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 1. Çok Katmanlı Dış Ortam Gölgeleri (Ambient Occlusion & Soft Drop)
    ctx.saveGState()
    // Geniş yumuşak gölge
    ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 46, color: NSColor.black.withAlphaComponent(0.20).cgColor)

    let docPath = CGMutablePath()
    docPath.move(to: CGPoint(x: docX + cornerRadius, y: docY))
    docPath.addArc(tangent1End: CGPoint(x: docX + docW, y: docY),
                   tangent2End: CGPoint(x: docX + docW, y: docY + docH),
                   radius: cornerRadius)
    docPath.addLine(to: CGPoint(x: docX + docW, y: docY + docH - foldSize))
    docPath.addLine(to: CGPoint(x: docX + docW - foldSize, y: docY + docH))
    docPath.addArc(tangent1End: CGPoint(x: docX, y: docY + docH),
                   tangent2End: CGPoint(x: docX, y: docY),
                   radius: cornerRadius)
    docPath.addArc(tangent1End: CGPoint(x: docX, y: docY),
                   tangent2End: CGPoint(x: docX + docW, y: docY),
                   radius: cornerRadius)
    docPath.closeSubpath()

    ctx.addPath(docPath)
    ctx.clip()

    // 2. Sıvı Buzlu Cam Tabanı (Frosted Translucent Glass Substrate)
    let glassColors = [
        NSColor(white: 0.98, alpha: 0.96).cgColor,
        NSColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 0.92).cgColor,
        NSColor(red: 0.91, green: 0.94, blue: 0.98, alpha: 0.90).cgColor,
        NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.94).cgColor
    ] as CFArray

    if let glassGrad = CGGradient(colorsSpace: colorSpace, colors: glassColors, locations: [0.0, 0.35, 0.70, 1.0]) {
        ctx.drawLinearGradient(glassGrad,
                               start: CGPoint(x: docX, y: docY + docH),
                               end: CGPoint(x: docX, y: docY),
                               options: [])
    }

    // Cam İçi Çapraz Işık Çizgisi (Refractive Light Sheen)
    let sheenColors = [
        NSColor.white.withAlphaComponent(0.25).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray
    if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(sheenGrad,
                               start: CGPoint(x: docX, y: docY + docH),
                               end: CGPoint(x: docX + docW * 0.7, y: docY + docH * 0.3),
                               options: [])
    }
    ctx.restoreGState()

    // 3. Sıvı Cam Dış Kenarlık (Double Specular Glass Rim)
    ctx.saveGState()
    ctx.addPath(docPath)
    ctx.setLineWidth(2.2)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(docPath)
    ctx.setLineWidth(1.0)
    ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. 3D Kıvrık Cam Köşe (Curved Glass Fold)
    ctx.saveGState()
    let foldPath = CGMutablePath()
    foldPath.move(to: CGPoint(x: docX + docW - foldSize, y: docY + docH))
    foldPath.addLine(to: CGPoint(x: docX + docW - foldSize, y: docY + docH - foldSize + 20))
    foldPath.addQuadCurve(to: CGPoint(x: docX + docW - foldSize + 20, y: docY + docH - foldSize),
                          control: CGPoint(x: docX + docW - foldSize, y: docY + docH - foldSize))
    foldPath.addLine(to: CGPoint(x: docX + docW, y: docY + docH - foldSize))
    foldPath.closeSubpath()

    // Katlama Altı Temas Gölgesi
    ctx.setShadow(offset: CGSize(width: -12, height: -14), blur: 24, color: NSColor.black.withAlphaComponent(0.26).cgColor)

    let foldColors = [
        NSColor(white: 0.97, alpha: 0.98).cgColor,
        NSColor(red: 0.84, green: 0.88, blue: 0.94, alpha: 0.92).cgColor
    ] as CFArray
    if let foldGrad = CGGradient(colorsSpace: colorSpace, colors: foldColors, locations: [0.0, 1.0]) {
        ctx.addPath(foldPath)
        ctx.clip()
        ctx.drawLinearGradient(foldGrad,
                               start: CGPoint(x: docX + docW - foldSize, y: docY + docH),
                               end: CGPoint(x: docX + docW, y: docY + docH - foldSize),
                               options: [])
    }
    ctx.restoreGState()

    // Katlama Kenar Parıltısı
    ctx.saveGState()
    ctx.addPath(foldPath)
    ctx.setLineWidth(1.8)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    // 5. Merkezi Coffer Kristal Lens Simgesi (Floating Glass Badge)
    let miniIconSize: CGFloat = 260
    let miniIconX: CGFloat = (canvasSize - miniIconSize) / 2
    let miniIconY: CGFloat = docY + docH - 395

    if let appImg = masterAppImage,
       let rep = appImg.representations.first as? NSBitmapImageRep,
       let cgApp = rep.cgImage {
        ctx.saveGState()
        let miniRect = CGRect(x: miniIconX, y: miniIconY, width: miniIconSize, height: miniIconSize)
        let miniPath = CGPath(roundedRect: miniRect, cornerWidth: 56, cornerHeight: 56, transform: nil)
        
        // Lens Gölgesi
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.20).cgColor)
        ctx.addPath(miniPath)
        ctx.clip()
        ctx.draw(cgApp, in: miniRect)

        // Üst Dışbükey Cam Parlama Yansıması (Convex Glass Glare)
        let glareColors = [
            NSColor.white.withAlphaComponent(0.35).cgColor,
            NSColor.white.withAlphaComponent(0.02).cgColor
        ] as CFArray
        if let glareGrad = CGGradient(colorsSpace: colorSpace, colors: glareColors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(glareGrad,
                                   start: CGPoint(x: miniIconX, y: miniIconY + miniIconSize),
                                   end: CGPoint(x: miniIconX, y: miniIconY + miniIconSize * 0.45),
                                   options: [])
        }
        ctx.restoreGState()

        // Kristal Çerçeve
        ctx.saveGState()
        let borderPath = CGPath(roundedRect: miniRect, cornerWidth: 56, cornerHeight: 56, transform: nil)
        ctx.addPath(borderPath)
        ctx.setLineWidth(2.0)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.50).cgColor)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // 6. Apple Liquid Glass Format Kapsülü (The Liquid Glass Gem Cartridge)
    let badgeW: CGFloat = 620
    let badgeH: CGFloat = 190
    let badgeX: CGFloat = (canvasSize - badgeW) / 2
    let badgeY: CGFloat = docY + 110
    let badgeCorner: CGFloat = 40

    ctx.saveGState()
    let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)
    let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: badgeCorner, cornerHeight: badgeCorner, transform: nil)

    // A. Neon Işıma Halosu (Liquid Neon Glow)
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 34, color: config.secondaryColor.withAlphaComponent(0.48).cgColor)

    // B. Sıvı Jel Taban Gradyanı (Multi-stop Liquid Gem Base)
    let badgeColors = [
        config.highlightColor.cgColor,
        config.secondaryColor.cgColor,
        config.primaryColor.cgColor
    ] as CFArray
    if let badgeGrad = CGGradient(colorsSpace: colorSpace, colors: badgeColors, locations: [0.0, 0.45, 1.0]) {
        ctx.addPath(badgePath)
        ctx.clip()
        ctx.drawLinearGradient(badgeGrad,
                               start: CGPoint(x: badgeX, y: badgeY + badgeH),
                               end: CGPoint(x: badgeX, y: badgeY),
                               options: [])
    }
    ctx.restoreGState()

    // C. Üst Kubbe Cam Yansıması (Specular Dome Glare)
    ctx.saveGState()
    ctx.addPath(badgePath)
    ctx.clip()

    let domeColors = [
        NSColor.white.withAlphaComponent(0.45).cgColor,
        NSColor.white.withAlphaComponent(0.04).cgColor
    ] as CFArray
    if let domeGrad = CGGradient(colorsSpace: colorSpace, colors: domeColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(domeGrad,
                               start: CGPoint(x: badgeX, y: badgeY + badgeH),
                               end: CGPoint(x: badgeX, y: badgeY + badgeH * 0.48),
                               options: [])
    }

    // D. Alt İç Kırılma Işığı (Bottom Caustic Bounce Light)
    let bottomLightColors = [
        NSColor.white.withAlphaComponent(0.0).cgColor,
        NSColor.white.withAlphaComponent(0.28).cgColor
    ] as CFArray
    if let bottomGrad = CGGradient(colorsSpace: colorSpace, colors: bottomLightColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(bottomGrad,
                               start: CGPoint(x: badgeX, y: badgeY + 40),
                               end: CGPoint(x: badgeX, y: badgeY),
                               options: [])
    }
    ctx.restoreGState()

    // E. Sıvı Cam Kontur Çerçevesi (Specular Rim Stroke)
    ctx.saveGState()
    ctx.addPath(badgePath)
    ctx.setLineWidth(2.0)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.70).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    // 7. Format Başlığı (3D Kabartmalı Cam Tipografi)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let fontSize: CGFloat = config.label.count > 4 ? 68 : 80
    let font = NSFont.systemFont(ofSize: fontSize, weight: .black)
    
    // Metin Alt Yumuşak Gölgesi
    let textShadow = NSShadow()
    textShadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
    textShadow.shadowOffset = NSSize(width: 0, height: -2.5)
    textShadow.shadowBlurRadius = 5

    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle,
        .shadow: textShadow,
        .kern: 3.5
    ]

    let textString = NSAttributedString(string: config.label, attributes: textAttrs)
    let textSize = textString.size()
    let textY = badgeY + (badgeH - textSize.height) / 2 + 16
    textString.draw(in: CGRect(x: badgeX, y: textY, width: badgeW, height: textSize.height))

    // 8. Alt Başlık İçin Buzlu Cam Mikro Kapsül (Frosted Glass Pill)
    let pillW: CGFloat = 340
    let pillH: CGFloat = 30
    let pillX: CGFloat = (canvasSize - pillW) / 2
    let pillY: CGFloat = badgeY + 18
    let pillRect = CGRect(x: pillX, y: pillY, width: pillW, height: pillH)
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil)

    ctx.saveGState()
    ctx.addPath(pillPath)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.fillPath()

    ctx.addPath(pillPath)
    ctx.setLineWidth(1.0)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    let subFont = NSFont.systemFont(ofSize: 13, weight: .heavy)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle,
        .kern: 2.4
    ]
    let subString = NSAttributedString(string: "✦  \(config.sublabel)", attributes: subAttrs)
    let subSize = subString.size()
    let subY = pillY + (pillH - subSize.height) / 2
    subString.draw(in: CGRect(x: pillX, y: subY, width: pillW, height: subSize.height))

    // 9. Belge Alt Taban Marka İmzası (UnPack)
    let brandStyle = NSMutableParagraphStyle()
    brandStyle.alignment = .center
    let brandAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor.black.withAlphaComponent(0.30),
        .paragraphStyle: brandStyle,
        .kern: 4.0
    ]
    let brandString = NSAttributedString(string: "UNPACK", attributes: brandAttrs)
    brandString.draw(in: CGRect(x: docX, y: docY + 36, width: docW, height: 26))

    image.unlockFocus()
    return image
}

// MARK: - Küçük Piksel Boyutları İçin Kristal Netliğinde Apple Liquid Glass Rozeti (16px, 32px, 64px)

func drawSmallDocumentIcon(config: DocIconConfig, targetSize: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: targetSize, height: targetSize))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.interpolationQuality = .high

    let pad: CGFloat = targetSize * 0.06
    let w = targetSize - (pad * 2)
    let h = targetSize - (pad * 2)
    let rect = CGRect(x: pad, y: pad, width: w, height: h)
    let r: CGFloat = targetSize * 0.22

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 1. Sıvı Neon Squircle Tabanı
    let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: targetSize * 0.12, color: config.secondaryColor.withAlphaComponent(0.50).cgColor)

    let badgeColors = [
        config.highlightColor.cgColor,
        config.secondaryColor.cgColor,
        config.primaryColor.cgColor
    ] as CFArray
    if let badgeGrad = CGGradient(colorsSpace: colorSpace, colors: badgeColors, locations: [0.0, 0.45, 1.0]) {
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(badgeGrad,
                               start: CGPoint(x: pad, y: pad + h),
                               end: CGPoint(x: pad, y: pad),
                               options: [])
    }
    ctx.restoreGState()

    // 2. Üst Kubbe Cam Parlaması
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let domeColors = [
        NSColor.white.withAlphaComponent(0.45).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray
    if let domeGrad = CGGradient(colorsSpace: colorSpace, colors: domeColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(domeGrad,
                               start: CGPoint(x: pad, y: pad + h),
                               end: CGPoint(x: pad, y: pad + h * 0.5),
                               options: [])
    }
    ctx.restoreGState()

    // 3. Parlak Beyaz Kenarlık (Specular Rim)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.65).cgColor)
    ctx.setLineWidth(targetSize <= 16 ? 0.8 : 1.2)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Net, Kalın Tipografi (Razor Sharp Format Label)
    let pStyle = NSMutableParagraphStyle()
    pStyle.alignment = .center

    let fontSize: CGFloat
    if targetSize <= 16 {
        fontSize = config.label.count > 4 ? 6.5 : 8.0
    } else if targetSize <= 32 {
        fontSize = config.label.count > 4 ? 11.5 : 14.5
    } else {
        fontSize = config.label.count > 4 ? 22.0 : 27.0
    }

    let font = NSFont.systemFont(ofSize: fontSize, weight: .black)
    let textShadow = NSShadow()
    textShadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
    textShadow.shadowOffset = NSSize(width: 0, height: -1)
    textShadow.shadowBlurRadius = 2

    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: pStyle,
        .shadow: textShadow
    ]
    let str = NSAttributedString(string: config.label, attributes: textAttrs)
    let sz = str.size()
    let ty = pad + (h - sz.height) / 2
    str.draw(in: CGRect(x: pad, y: ty, width: w, height: sz.height))

    image.unlockFocus()
    return image
}

// MARK: - İkonset Üretimi ve Derleme

for config in configs {
    let iconsetName = "\(config.name).iconset"
    let iconsetPath = "\(buildDir)/\(iconsetName)"
    let icnsPath = "\(buildDir)/\(config.name).icns"

    try? fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

    let masterDocImage = drawLargeDocumentIcon(config: config, canvasSize: 1024)

    guard let tiff = masterDocImage.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let cgLarge = rep.cgImage else {
        print("Error creating CGImage for \(config.name)")
        continue
    }

    for (name, sz) in iconSizes {
        let destImg: NSImage
        if sz <= 32 {
            destImg = drawSmallDocumentIcon(config: config, targetSize: sz)
        } else {
            destImg = NSImage(size: NSSize(width: sz, height: sz))
            destImg.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.interpolationQuality = .high
                ctx.draw(cgLarge, in: CGRect(x: 0, y: 0, width: sz, height: sz))
            }
            destImg.unlockFocus()
        }

        if let destTiff = destImg.tiffRepresentation,
           let destRep = NSBitmapImageRep(data: destTiff),
           let pngData = destRep.representation(using: .png, properties: [:]) {
            let destFile = "\(iconsetPath)/\(name)"
            try? pngData.write(to: URL(fileURLWithPath: destFile))
        }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
    try? process.run()
    process.waitUntilExit()

    print("==> Liquid Glass Generated: \(icnsPath)")
}

print("==> All Apple Liquid Glass document icons generated successfully!")
