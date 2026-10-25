import Foundation
import SwiftUI

/// Arşiv içerisindeki her bir dosya veya klasörün metadata modeli
/// Bellek ve işlemci optimizasyonu için türetilmiş alanlar tek seferde hesaplanır ve önbelleğe alınır.
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

    // Yüksek Performanslı Önbelleğe Alınmış Alanlar (Sıfır Ek Tahsisat)
    public let fileExtension: String
    public let lowerName: String
    public let lowerPath: String
    public let formattedUncompressedSize: String
    public let formattedCompressedSize: String
    public let formattedRatio: String
    public let compressionRatio: Double

    // Global Paylaşımlı Statik Boyut Formatlayıcı (Tek defa oluşturulur)
    private static let sharedByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter
    }()

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

        // 3. Klasör tespiti
        let isDir = isDirectory || cleanPath.hasSuffix("/")

        // 4. Sondaki tüm / işaretlerini temizle
        while cleanPath.hasSuffix("/") {
            cleanPath.removeLast()
        }

        self.path = cleanPath
        self.isDirectory = isDir

        // 5. Yüksek Hızlı Yol Ayrıştırma (Dizi/Split tahsisi yapmadan tek geçişte)
        if let lastSlash = cleanPath.lastIndex(of: "/") {
            self.name = String(cleanPath[cleanPath.index(after: lastSlash)...])
            self.parentPath = String(cleanPath[..<lastSlash])
        } else {
            self.name = cleanPath
            self.parentPath = ""
        }

        self.uncompressedSize = uncompressedSize
        let finalCompressed = compressedSize > 0 ? compressedSize : uncompressedSize
        self.compressedSize = finalCompressed
        self.modificationDate = modificationDate
        self.isEncrypted = isEncrypted
        self.crc32 = crc32

        // 6. Dosya Uzantısı (NSString köprülemesi olmadan yerel Swift indeks taraması)
        if isDir {
            self.fileExtension = ""
        } else if let lastDot = self.name.lastIndex(of: "."), lastDot != self.name.startIndex {
            self.fileExtension = String(self.name[self.name.index(after: lastDot)...]).lowercased()
        } else {
            self.fileExtension = ""
        }

        // 7. Arama İndeksi İçin Küçük Harf Önbelleği
        self.lowerName = self.name.lowercased()
        self.lowerPath = cleanPath.lowercased()

        // 8. Sıkıştırma Oranı ve Formatlanmış Boyutlar (Önceden hesaplanır)
        if isDir {
            self.compressionRatio = 0.0
            self.formattedUncompressedSize = "--"
            self.formattedCompressedSize = "--"
            self.formattedRatio = "--"
        } else {
            if uncompressedSize > 0 {
                let ratio = (1.0 - (Double(finalCompressed) / Double(uncompressedSize))) * 100.0
                let clampedRatio = max(0.0, min(ratio, 99.9))
                self.compressionRatio = clampedRatio
                self.formattedRatio = String(format: "%%%0.1f", clampedRatio)
            } else {
                self.compressionRatio = 0.0
                self.formattedRatio = "--"
            }
            self.formattedUncompressedSize = Self.sharedByteFormatter.string(fromByteCount: uncompressedSize)
            self.formattedCompressedSize = Self.sharedByteFormatter.string(fromByteCount: finalCompressed)
        }
    }

    public static func == (lhs: ArchiveItem, rhs: ArchiveItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Sıralama için güvenli karşılaştırılabilir tarih
    public var modificationDateComparable: Date {
        modificationDate ?? Date.distantPast
    }

    /// Sıralama için güvenli CRC32
    public var crc32Sortable: String {
        crc32 ?? ""
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
