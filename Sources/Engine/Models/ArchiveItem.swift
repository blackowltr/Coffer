import Foundation
import SwiftUI

/// Arşiv içerisindeki her bir dosya veya klasörün metadata modeli
public struct ArchiveItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let path: String               // Örn: "Belgeler/Raporlar/Mali_2026.pdf"
    public let name: String               // Örn: "Mali_2026.pdf"
    public let parentPath: String         // Örn: "Belgeler/Raporlar"
    public let uncompressedSize: Int64    // Orijinal boyut (byte)
    public let compressedSize: Int64      // Sıkıştırılmış boyut (byte)
    public let modificationDate: Date?    // Son değiştirilme tarihi
    public let isDirectory: Bool          // Klasör mü?
    public let isEncrypted: Bool          // Şifreli mi?
    public let crc32: String?             // Hex CRC32 (örn: "4F1A8C9E")

    public init(
        id: UUID = UUID(),
        path: String,
        uncompressedSize: Int64,
        compressedSize: Int64 = 0,
        modificationDate: Date? = nil,
        isDirectory: Bool = false,
        isEncrypted: Bool = false,
        crc32: String? = nil
    ) {
        self.id = id
        // 1. Ters eğik çizgileri (Windows / WinRAR '\') düz çizgiye '/' çevir
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\", with: "/")

        // 2. Baştaki ./ veya / işaretlerini sil
        while cleanPath.hasPrefix("./") {
            cleanPath.removeFirst(2)
        }
        while cleanPath.hasPrefix("/") {
            cleanPath.removeFirst()
        }

        // 3. Klasör olup olmadığını tespit et (sonunda / varsa klasördür)
        let isDir = isDirectory || cleanPath.hasSuffix("/")

        // 4. Sondaki tüm / işaretlerini temizle (böylece klasör ile dosya yolları standartlaşır)
        while cleanPath.hasSuffix("/") {
            cleanPath.removeLast()
        }

        self.path = cleanPath
        self.isDirectory = isDir

        let components = cleanPath.split(separator: "/").map(String.init)
        self.name = components.last ?? cleanPath
        if components.count > 1 {
            self.parentPath = components.dropLast().joined(separator: "/")
        } else {
            self.parentPath = ""
        }

        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize > 0 ? compressedSize : uncompressedSize
        self.modificationDate = modificationDate
        self.isEncrypted = isEncrypted
        self.crc32 = crc32
    }

    /// Sıralama için güvenli karşılaştırılabilir tarih
    public var modificationDateComparable: Date {
        modificationDate ?? Date.distantPast
    }

    /// Sıralama için güvenli CRC32
    public var crc32Sortable: String {
        crc32 ?? ""
    }

    /// Sıkıştırma oranı (örn: %45 tasarruf)
    public var compressionRatio: Double {
        guard uncompressedSize > 0 else { return 0.0 }
        let ratio = (1.0 - (Double(compressedSize) / Double(uncompressedSize))) * 100.0
        return max(0.0, min(ratio, 99.9))
    }

    /// Dosya uzantısı
    public var fileExtension: String {
        guard !isDirectory else { return "" }
        return (name as NSString).pathExtension.lowercased()
    }

    /// Okunabilir orijinal boyut formatı
    public var formattedUncompressedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }

    /// Okunabilir sıkıştırılmış boyut formatı
    public var formattedCompressedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    /// Okunabilir sıkıştırma oranı metni
    public var formattedRatio: String {
        if isDirectory { return "--" }
        return String(format: "%%%0.1f", compressionRatio)
    }

    /// Dosya tipine uygun SF Symbol simgesi
    public var iconName: String {
        if isDirectory { return "folder.fill" }

        switch fileExtension {
        case "pdf": return "doc.richtext.fill"
        case "doc", "docx", "pages", "txt", "rtf", "md": return "doc.text.fill"
        case "xls", "xlsx", "numbers", "csv": return "tablecells.fill"
        case "ppt", "pptx", "key": return "play.rectangle.fill"
        case "png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "bmp", "tiff": return "photo.fill"
        case "mp4", "mov", "mkv", "avi", "webm", "m4v": return "film.fill"
        case "mp3", "m4a", "flac", "wav", "aac", "ogg": return "music.note"
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz": return "archivebox.fill"
        case "swift", "c", "cpp", "h", "hpp", "py", "js", "ts", "html", "css", "json", "xml", "sh": return "chevron.left.forwardslash.chevron.right"
        case "dmg", "iso": return "opticaldisc.fill"
        case "app": return "app.dashed"
        default: return "doc.fill"
        }
    }

    /// Simge rengi
    public var iconColor: Color {
        if isDirectory { return AppSettings.shared.accentColorChoice.color }
        switch fileExtension {
        case "pdf": return .red
        case "doc", "docx", "pages", "txt", "md": return .blue
        case "xls", "xlsx", "numbers", "csv": return .green
        case "ppt", "pptx", "key": return .indigo
        case "png", "jpg", "jpeg", "heic", "webp": return .purple
        case "mp4", "mov", "mkv": return .pink
        case "mp3", "m4a", "flac": return .cyan
        case "zip", "rar", "7z": return AppSettings.shared.accentColorChoice.color
        case "swift", "py", "js", "cpp": return .teal
        default: return .secondary
        }
    }
}
