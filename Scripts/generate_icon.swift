import AppKit
import CoreGraphics

let fileManager = FileManager.default
let projectDir = FileManager.default.currentDirectoryPath
let masterIconPath = "\(projectDir)/Resources/AppIcon_1024.png"
let iconsetDir = "\(projectDir)/build/AppIcon.iconset"

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

if let masterImg = NSImage(contentsOfFile: masterIconPath),
   let tiff = masterImg.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let cgImage = rep.cgImage {

    for (name, sz) in sizes {
        let destImg = NSImage(size: NSSize(width: sz, height: sz))
        destImg.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: sz, height: sz))
        }
        destImg.unlockFocus()

        if let destTiff = destImg.tiffRepresentation,
           let destRep = NSBitmapImageRep(data: destTiff),
           let pngData = destRep.representation(using: .png, properties: [:]) {
            let dest = "\(iconsetDir)/\(name)"
            try? pngData.write(to: URL(fileURLWithPath: dest))
        }
    }
    print("Iconset generated successfully from master icon at \(iconsetDir)")
} else {
    print("Warning: Master icon not found at \(masterIconPath)")
}
