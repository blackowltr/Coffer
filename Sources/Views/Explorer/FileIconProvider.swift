import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Yüksek çözünürlüklü ve yerel macOS dosya/klasör simgelerini sağlayan,
/// bellek baskısında kendini otomatik temizleyen yüksek verimli sağlayıcı
public final class FileIconProvider: @unchecked Sendable {
    public static let shared = FileIconProvider()

    private let cache = NSCache<NSString, NSImage>()
    public let folderIcon: NSImage
    public let defaultFileIcon: NSImage

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 16 * 1024 * 1024 // Maksimum 16 MB simge önbelleği

        let folder = NSWorkspace.shared.icon(for: .folder)
        folder.size = NSSize(width: 64, height: 64)
        self.folderIcon = folder

        let generic = NSWorkspace.shared.icon(for: .item)
        generic.size = NSSize(width: 64, height: 64)
        self.defaultFileIcon = generic
        self.cache.setObject(generic, forKey: "__default_file__")

        prewarmArchiveIcons()
    }

    /// Uygulama paketindeki (.app/Contents/Resources) yüksek çözünürlüklü belge simgesini yükler
    private func loadBundledIcon(named name: String) -> NSImage? {
        if let img = Bundle.main.image(forResource: NSImage.Name(name)) {
            img.size = NSSize(width: 64, height: 64)
            return img
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 64, height: 64)
            return img
        }
        return nil
    }

    private func prewarmArchiveIcons() {
        let archiveMappings: [String: String] = [
            "rar": "RarDocIcon",
            "cbr": "RarDocIcon",
            "rev": "RarDocIcon",
            "zip": "ZipDocIcon",
            "zipx": "ZipDocIcon",
            "cbz": "ZipDocIcon",
            "7z": "SevenZipDocIcon",
            "tar": "TarDocIcon",
            "gz": "TarDocIcon",
            "tgz": "TarDocIcon",
            "bz2": "TarDocIcon",
            "tbz2": "TarDocIcon",
            "xz": "TarDocIcon",
            "txz": "TarDocIcon",
            "zst": "TarDocIcon",
            "iso": "ArchiveDocIcon",
            "dmg": "ArchiveDocIcon",
            "img": "ArchiveDocIcon",
            "cab": "ArchiveDocIcon",
            "wim": "ArchiveDocIcon",
            "pkg": "ArchiveDocIcon"
        ]

        for (ext, iconName) in archiveMappings {
            if let customImg = loadBundledIcon(named: iconName) {
                cache.setObject(customImg, forKey: ext as NSString)
            }
        }
    }

    /// Dosya veya klasör için yerel, yüksek kaliteli macOS simgesini döner (Düşük bellek ve CPU)
    public func icon(for item: ArchiveItem) -> NSImage {
        if item.isDirectory {
            return folderIcon
        }

        let ext = item.fileExtension
        if ext.isEmpty {
            return defaultFileIcon
        }

        let key = ext as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // Özel simge kontrolü
        let iconName: String?
        switch ext {
        case "rar", "cbr", "rev":
            iconName = "RarDocIcon"
        case "zip", "zipx", "cbz":
            iconName = "ZipDocIcon"
        case "7z":
            iconName = "SevenZipDocIcon"
        case "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst":
            iconName = "TarDocIcon"
        case "iso", "dmg", "img", "cab", "wim", "pkg":
            iconName = "ArchiveDocIcon"
        default:
            iconName = nil
        }

        let resolvedIcon: NSImage
        if let name = iconName, let bundled = loadBundledIcon(named: name) {
            resolvedIcon = bundled
        } else if let utType = UTType(filenameExtension: ext) {
            resolvedIcon = NSWorkspace.shared.icon(for: utType)
            resolvedIcon.size = NSSize(width: 64, height: 64)
        } else {
            resolvedIcon = defaultFileIcon
        }

        cache.setObject(resolvedIcon, forKey: key)
        return resolvedIcon
    }
}
