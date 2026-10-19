import Foundation
import AppKit

/// Akıllı Çıkarma & Klasör Bombası (Anti-Folder-Bomb) Koruması
public final class SmartExtractor: Sendable {
    public static let shared = SmartExtractor()

    private init() {}

    /// Hedef çıkarma yolunu arşiv yapısına göre akıllıca belirler
    public func resolveDestinationPath(
        archiveURL: URL,
        items: [ArchiveItem],
        baseDestinationURL: URL,
        enableSmartExtraction: Bool
    ) -> (resolvedURL: URL, createdNewFolder: Bool) {
        guard enableSmartExtraction else {
            // Akıllı çıkarma kapalıysa doğrudan temel dizine çıkar
            return (baseDestinationURL, false)
        }

        // Arşiv içindeki kök düzeyindeki benzersiz öğeleri tespit et (Junk kalıntılarını filtrele)
        var rootComponents = Set<String>()
        for item in items {
            if AppleJunkSanitizer.shared.isJunk(path: item.path) {
                continue // .DS_Store, __MACOSX vb. kök klasör hesabını bozmasın
            }
            let parts = item.path.split(separator: "/")
            if let first = parts.first {
                rootComponents.insert(String(first))
            }
        }

        // Eğer arşivde yalnızca 1 adet kök klasör varsa klasör bombası riski yoktur
        if rootComponents.count == 1, let singleRoot = rootComponents.first,
           items.filter({ !AppleJunkSanitizer.shared.isJunk(path: $0.path) }).allSatisfy({ $0.path.hasPrefix(singleRoot + "/") || $0.path == singleRoot }) {
            return (baseDestinationURL, false)
        }

        // Birden fazla dağınık kök dosyası/klasörü varsa:
        // Masaüstünü veya hedef klasörü korumak için arşiv adında özel bir alt klasör oluştur
        let folderName = (archiveURL.lastPathComponent as NSString).deletingPathExtension
        let safeFolderURL = baseDestinationURL.appendingPathComponent(folderName)
        return (safeFolderURL, true)
    }

    /// Çıkarma sonrası otomasyon eylemlerini (Artıkları Temizle, Çöpe Taşı, Finder'da Aç, Ses) yürütür
    public func performPostExtractionActions(
        archiveURL: URL,
        destinationURL: URL,
        trashOriginal: Bool,
        revealInFinder: Bool,
        playSound: Bool
    ) {
        // Hedef dizindeki tüm macOS artıklarını derhal temizle
        if AppSettings.shared.stripMacJunkFiles {
            _ = AppleJunkSanitizer.shared.sanitizeDirectory(at: destinationURL)
        }

        if trashOriginal {
            try? FileManager.default.trashItem(at: archiveURL, resultingItemURL: nil)
        }

        if playSound {
            NSSound.beep()
        }

        if revealInFinder {
            DispatchQueue.main.async {
                NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: "")
            }
        }
    }
}
