import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Yüksek çözünürlüklü ve yerel macOS dosya/klasör simgelerini sağlayan ve önbelleğe alan modern sağlayıcı
public final class FileIconProvider {
    public static let shared = FileIconProvider()

    private var cache = [String: NSImage]()
    private let folderIcon: NSImage

    private init() {
        // macOS yerel retina klasör simgesi
        let folder = NSWorkspace.shared.icon(for: .folder)
        folder.size = NSSize(width: 32, height: 32)
        self.folderIcon = folder
    }

    /// Dosya veya klasör için yerel, yüksek kaliteli macOS simgesini döner
    public func icon(for item: ArchiveItem) -> NSImage {
        if item.isDirectory {
            return folderIcon
        }

        let ext = item.fileExtension.lowercased()
        if ext.isEmpty {
            if let cached = cache["__default_file__"] {
                return cached
            }
            let generic = NSWorkspace.shared.icon(for: .item)
            generic.size = NSSize(width: 32, height: 32)
            cache["__default_file__"] = generic
            return generic
        }

        if let cached = cache[ext] {
            return cached
        }

        let sysIcon: NSImage
        if let utType = UTType(filenameExtension: ext) {
            sysIcon = NSWorkspace.shared.icon(for: utType)
        } else {
            sysIcon = NSWorkspace.shared.icon(for: .data)
        }

        sysIcon.size = NSSize(width: 32, height: 32)
        cache[ext] = sysIcon
        return sysIcon
    }
}
