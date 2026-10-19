import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Yüksek çözünürlüklü ve yerel macOS dosya/klasör simgelerini sağlayan ve önbelleğe alan yüksek performanslı sağlayıcı
public final class FileIconProvider: @unchecked Sendable {
    public static let shared = FileIconProvider()

    private var cache = [String: NSImage]()
    private let folderIcon: NSImage
    private let defaultFileIcon: NSImage
    private let lock = NSLock()

    private init() {
        let folder = NSWorkspace.shared.icon(for: .folder)
        folder.size = NSSize(width: 32, height: 32)
        self.folderIcon = folder

        let generic = NSWorkspace.shared.icon(for: .item)
        generic.size = NSSize(width: 32, height: 32)
        self.defaultFileIcon = generic
        self.cache["__default_file__"] = generic

        // En yaygın uzantıları önceden ısıtarak UI gezinmesinde takılmaları (IPC beklemesini) önle
        prewarmCommonExtensions()
    }

    private func prewarmCommonExtensions() {
        let common = [
            "zip", "rar", "7z", "tar", "gz", "bz2", "xz",
            "pdf", "txt", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "png", "jpg", "jpeg", "heic", "webp", "gif", "svg",
            "mp4", "mov", "mkv", "mp3", "wav", "m4a", "flac",
            "swift", "py", "js", "ts", "html", "css", "json", "xml", "sh", "md"
        ]
        for ext in common {
            let sysIcon: NSImage
            if let utType = UTType(filenameExtension: ext) {
                sysIcon = NSWorkspace.shared.icon(for: utType)
            } else {
                sysIcon = defaultFileIcon
            }
            sysIcon.size = NSSize(width: 32, height: 32)
            cache[ext] = sysIcon
        }
    }

    /// Dosya veya klasör için yerel, yüksek kaliteli macOS simgesini döner
    public func icon(for item: ArchiveItem) -> NSImage {
        if item.isDirectory {
            return folderIcon
        }

        let ext = item.fileExtension
        if ext.isEmpty {
            return defaultFileIcon
        }

        lock.lock()
        if let cached = cache[ext] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let sysIcon: NSImage
        if let utType = UTType(filenameExtension: ext) {
            sysIcon = NSWorkspace.shared.icon(for: utType)
        } else {
            sysIcon = defaultFileIcon
        }
        sysIcon.size = NSSize(width: 32, height: 32)

        lock.lock()
        cache[ext] = sysIcon
        lock.unlock()

        return sysIcon
    }
}
