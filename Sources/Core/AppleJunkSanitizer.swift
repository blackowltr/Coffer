import Foundation

/// macOS çöp ve artık dosyalarını (.DS_Store, __MACOSX, ._* AppleDouble, extended attributes)
/// derinlemesine temizleyen optimize edilmiş profesyonel temizlik motoru
public final class AppleJunkSanitizer: Sendable {
    public static let shared = AppleJunkSanitizer()

    /// Filtrelenecek bilinen macOS ve gereksiz sistem artık kalıpları
    public static let junkPatterns: [String] = [
        ".DS_Store",
        "._.DS_Store",
        "._*",
        "__MACOSX",
        ".AppleDouble",
        ".AppleDesktop",
        ".Spotlight-V100",
        ".Trashes",
        ".fseventsd",
        ".VolumeIcon.icns",
        ".apdisk",
        "Thumbs.db",
        "ehthumbs.db",
        "desktop.ini"
    ]

    private init() {}

    /// Verilen dosya adının veya yolunun macOS / sistem artığı olup olmadığını kapsamlı ve yüksek hızda kontrol eder
    public func isJunk(path: String) -> Bool {
        guard !path.isEmpty else { return false }

        // 1. En yaygın macOS artık kalıpları (Hızlı alt dize araması - Sıfır tahsisat)
        if path.contains("__MACOSX") || path.contains(".DS_Store") {
            return true
        }

        // 2. AppleDouble kaynak çatalı (Resource Fork) kalıntıları (örn: ._dosya.jpg veya /path/._dosya.jpg)
        if path.hasPrefix("._") || path.contains("/._") || path.contains("\\._") {
            return true
        }

        // 3. Dosya adını belirle (Hızlı indeks araması)
        let filename: Substring
        if let idx = path.lastIndex(where: { $0 == "/" || $0 == "\\" }) {
            filename = path[path.index(after: idx)...]
        } else {
            filename = path[...]
        }

        guard !filename.isEmpty else { return false }

        // 4. Sabit sistem artık adları
        if filename == ".AppleDouble" || filename == ".AppleDesktop" ||
           filename == ".Spotlight-V100" || filename == ".Trashes" ||
           filename == ".fseventsd" || filename == ".VolumeIcon.icns" ||
           filename == ".apdisk" {
            return true
        }

        // 5. Windows önbellek kalıntıları
        if filename.caseInsensitiveCompare("thumbs.db") == .orderedSame ||
           filename.caseInsensitiveCompare("ehthumbs.db") == .orderedSame ||
           filename.caseInsensitiveCompare("desktop.ini") == .orderedSame {
            return true
        }

        return false
    }

    /// Bir dizindeki tüm geçici Mac artıklarını ve görünmez extended attribute kalıntılarını temizler
    @discardableResult
    public func sanitizeDirectory(at directoryURL: URL) -> Int {
        var removedCount = 0
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
            options: []
        ) else { return 0 }

        var itemsToDelete: [URL] = []
        for case let fileURL as URL in enumerator {
            if isJunk(path: fileURL.path) {
                itemsToDelete.append(fileURL)
            }
        }

        // Derinlik sırasına göre sil (En içteki dosyalardan başlayıp boş klasörlere doğru)
        for url in itemsToDelete.sorted(by: { $0.path.count > $1.path.count }) {
            do {
                try FileManager.default.removeItem(at: url)
                removedCount += 1
            } catch {
                // Silinemezse devam et
            }
        }

        // Kalan dosyalardaki com.apple.quarantine vb. genişletilmiş öznitelikleri (xattr) sıfırla
        stripExtendedAttributes(at: directoryURL)

        return removedCount
    }

    /// Dizindeki tüm dosyalardan com.apple.quarantine ve metadata özniteliklerini temizler
    public func stripExtendedAttributes(at directoryURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-rc", directoryURL.path]
        try? process.run()
        process.waitUntilExit()
    }

    /// Açık veya hedef bir arşiv içerisindeki tüm Mac artıklarını tespit eder ve siler
    @discardableResult
    public func cleanArchiveFromMacJunk(archiveURL: URL) async throws -> Int {
        let ext = archiveURL.pathExtension.lowercased()

        // 1. ZIP Arşivleri için doğrudan in-place ultra hızlı zip -d temizliği
        if ext == "zip" {
            let (itemsBefore, _) = try await ArchiveManager.shared.openArchive(at: archiveURL)
            let junkCount = itemsBefore.filter { isJunk(path: $0.path) }.count

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = [
                "-d", archiveURL.path,
                "__MACOSX*", "*/__MACOSX*",
                "*.DS_Store*", "*/.DS_Store*",
                "*._*", "*/._*",
                "*.Spotlight-V100*", "*/.Spotlight-V100*",
                "*.Trashes*", "*/.Trashes*",
                "*.fseventsd*", "*/.fseventsd*",
                "*Thumbs.db*", "*/Thumbs.db*",
                "*desktop.ini*", "*/desktop.ini*"
            ]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            try? process.run()
            process.waitUntilExit()

            // ZIP çıkış kodu 0 (başarılı) veya 12 (silinecek eşleşen öğe kalmadı) geçerlidir
            let (itemsAfter, _) = (try? await ArchiveManager.shared.openArchive(at: archiveURL)) ?? ([], ArchiveMetadata(format: .zip, archiveURL: archiveURL, totalFileCount: 0, totalDirectoryCount: 0, totalUncompressedSize: 0, archiveFileSize: 0, isEncrypted: false, isMultiVolume: false, hasRecoveryRecord: false))
            let remainingJunk = itemsAfter.filter { isJunk(path: $0.path) }.count

            return max(0, junkCount - remainingJunk)
        }

        // 2. Diğer arşiv formatları (TAR, TAR.GZ, TAR.BZ2, TAR.XZ vb.) için yeniden paketleme
        let (items, _) = try await ArchiveManager.shared.openArchive(at: archiveURL)
        let junkItems = items.filter { isJunk(path: $0.path) }

        guard !junkItems.isEmpty else {
            return 0
        }

        try await ArchiveManager.shared.deleteItems(from: archiveURL, items: junkItems)
        return junkItems.count
    }

    /// Sıkıştırma öncesinde kaynak dosya listesini filtreler (doğrudan seçilmiş .DS_Store vb. varsa atar)
    public func filterSourceURLs(_ urls: [URL]) -> [URL] {
        return urls.filter { !isJunk(path: $0.path) }
    }
}
