import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Yüksek çözünürlüklü ve yerel macOS dosya/klasör simgelerini sağlayan ve önbelleğe alan yüksek performanslı sağlayıcı
public final class FileIconProvider: @unchecked Sendable {
    public static let shared = FileIconProvider()

    private var cache = [String: NSImage]()
    public let folderIcon: NSImage
    public let defaultFileIcon: NSImage
    private let lock = NSLock()

    private init() {
        let folder = NSWorkspace.shared.icon(for: .folder)
        folder.size = NSSize(width: 64, height: 64)
        self.folderIcon = folder

        let generic = NSWorkspace.shared.icon(for: .item)
        generic.size = NSSize(width: 64, height: 64)
        self.defaultFileIcon = generic
        self.cache["__default_file__"] = generic

        // Özel Apple Liquid Glass belge simgelerini ve yaygın uzantıları önbelleğe al
        prewarmIcons()
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

    private func prewarmIcons() {
        // 1. Özel Arşiv Formatı Simgeleri (Apple Liquid Glass)
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
                cache[ext] = customImg
            }
        }

        // 2. Yaygın Dosya Uzantıları (macOS Native Simgeler)
        let commonExtensions = [
            "pdf", "txt", "rtf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv",
            "png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "tiff", "psd", "ai", "icns",
            "mp4", "mov", "mkv", "avi", "mp3", "wav", "m4a", "flac", "aac",
            "swift", "py", "js", "ts", "html", "css", "json", "xml", "sh", "md", "c", "cpp", "h", "sql", "yaml", "yml"
        ]

        for ext in commonExtensions {
            if cache[ext] == nil {
                let sysIcon: NSImage
                if let utType = UTType(filenameExtension: ext) {
                    sysIcon = NSWorkspace.shared.icon(for: utType)
                } else {
                    sysIcon = defaultFileIcon
                }
                sysIcon.size = NSSize(width: 64, height: 64)
                cache[ext] = sysIcon
            }
        }
    }

    /// Dosya veya klasör için yerel, yüksek kaliteli macOS simgesini döner
    public func icon(for item: ArchiveItem) -> NSImage {
        if item.isDirectory {
            return folderIcon
        }

        let ext = item.fileExtension.lowercased()
        if ext.isEmpty {
            return defaultFileIcon
        }

        lock.lock()
        if let cached = cache[ext] {
            lock.unlock()
            return cached
        }
        lock.unlock()

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

        lock.lock()
        cache[ext] = resolvedIcon
        lock.unlock()

        return resolvedIcon
    }
}
