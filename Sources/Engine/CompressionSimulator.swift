import Foundation

/// Sıkıştırma öncesi canlı boyut tasarrufu, hız ve süre simülatörü
public final class CompressionSimulator: Sendable {
    public static let shared = CompressionSimulator()

    /// Kaynak dosya ve klasörlerin statik analizi (Önbellek amaçlı)
    public struct SourceStats: Sendable {
        public let totalSize: Int64
        public let highlyCompressibleBytes: Int64
        public let alreadyCompressedBytes: Int64
        public let regularBytes: Int64
        public let fileCount: Int
        public let isSampleReference: Bool

        public static let sampleReference = SourceStats(
            totalSize: 1024 * 1024 * 1024, // 1 GB Referans Karma Veri
            highlyCompressibleBytes: 450 * 1024 * 1024, // 450 MB Metin/Kod/Doküman
            alreadyCompressedBytes: 350 * 1024 * 1024, // 350 MB Medya/Video/Görsel
            regularBytes: 224 * 1024 * 1024, // 224 MB Diğer İkililer
            fileCount: 120,
            isSampleReference: true
        )
    }

    /// Canlı simülasyon ve referans çıktısı
    public struct SimulationResult: Sendable {
        public let originalTotalSize: Int64
        public let estimatedCompressedSize: Int64
        public let savingsPercentage: Double
        public let estimatedDurationSeconds: Double
        public let mediaRatio: Double        // Zaten sıkışmış dosyalar oranı (PNG, MP4 vb.)
        public let compressibleRatio: Double // Yüksek sıkıştırılabilir metin/kod oranı
        public let regularRatio: Double      // Diğer ikili dosyalar
        public let speedScore: Double         // 0.0 ... 1.0 (Hız göstergesi)
        public let compressionScore: Double   // 0.0 ... 1.0 (Sıkıştırma verimi göstergesi)
        public let speedLabel: String         // e.g. "Işık Hızı (~0.2 sn)"
        public let formatBadge: String        // e.g. "Evrensel Uyumlu"
        public let formatDescription: String  // Formatın referans açıklaması
        public let levelDescription: String   // Seviyenin referans açıklaması
        public let isSampleReference: Bool
        public let fileCount: Int
    }

    private init() {}

    /// Verilen dosya ve klasörleri önceden tarar ve istatistiği önbelleğe alır
    public func analyzeSources(urls: [URL]) -> SourceStats {
        guard !urls.isEmpty else {
            return SourceStats.sampleReference
        }

        var totalSize: Int64 = 0
        var highlyCompressibleBytes: Int64 = 0
        var alreadyCompressedBytes: Int64 = 0
        var regularBytes: Int64 = 0
        var fileCount = 0

        for url in urls {
            analyzeItem(
                at: url,
                totalSize: &totalSize,
                highly: &highlyCompressibleBytes,
                already: &alreadyCompressedBytes,
                regular: &regularBytes,
                fileCount: &fileCount
            )
        }

        if totalSize <= 0 {
            return SourceStats.sampleReference
        }

        return SourceStats(
            totalSize: totalSize,
            highlyCompressibleBytes: highlyCompressibleBytes,
            alreadyCompressedBytes: alreadyCompressedBytes,
            regularBytes: regularBytes,
            fileCount: max(1, fileCount),
            isSampleReference: false
        )
    }

    /// Önbelleğe alınmış istatistikler üzerinden anında (0ms) canlı simülasyon yapar
    public func simulate(
        stats: SourceStats,
        format: ArchiveFormat,
        level: CompressionLevel
    ) -> SimulationResult {
        let totalSize = stats.totalSize
        if totalSize == 0 {
            return simulate(stats: SourceStats.sampleReference, format: format, level: level)
        }

        // Seviye çarpanları (Küçülme ve Süre)
        let levelMultiplier: Double
        let speedMultiplier: Double
        let levelDesc: String

        switch level {
        case .store:
            levelMultiplier = 1.0
            speedMultiplier = 1.0
            levelDesc = "Depola: Sıfır CPU tüketimi, disk hızında anında paketleme."
        case .fastest:
            levelMultiplier = 0.88
            speedMultiplier = 0.95
            levelDesc = "En Hızlı: Düşük CPU yükü ve minimum gecikme."
        case .fast:
            levelMultiplier = 0.78
            speedMultiplier = 0.85
            levelDesc = "Hızlı: Günlük kullanım için seri arşivleme."
        case .normal:
            levelMultiplier = 0.68
            speedMultiplier = 0.70
            levelDesc = "Normal: Hız ve dosya boyutu arasında ideal altın oran."
        case .good:
            levelMultiplier = 0.58
            speedMultiplier = 0.52
            levelDesc = "İyi: Gelişmiş veri analizi ile yüksek sıkıştırma."
        case .best:
            levelMultiplier = 0.48
            speedMultiplier = 0.35
            levelDesc = "En İyi: Çoklu çekirdek gücüyle mümkün olan en küçük arşiv boyutu."
        }

        // Format çarpanları, baz throughput ve karakteristikler
        let formatMultiplier: Double
        let baseThroughputMBps: Double
        let formatBadge: String
        let formatDesc: String
        var formatCompScore: Double
        var formatSpeedScore: Double

        switch format {
        case .rar:
            formatMultiplier = 0.82
            baseThroughputMBps = 240.0
            formatBadge = "👑 Orijinal WinRAR"
            formatDesc = "Resmi RAR5 formatı. Güçlü sıkıştırma, kurtarma kaydı ve şifreleme desteği."
            formatCompScore = 0.90
            formatSpeedScore = 0.80

        case .tar:
            formatMultiplier = 1.0
            baseThroughputMBps = 900.0
            formatBadge = "📦 Saf Paketleme"
            formatDesc = "Sıkıştırmasız arşiv. Dosyaları salt tek parça haline getirir, sıfır CPU harcar."
            formatCompScore = 0.05
            formatSpeedScore = 1.0

        case .tarGz:
            formatMultiplier = 0.92
            baseThroughputMBps = 420.0
            formatBadge = "⚡️ Ultra Hızlı Gzip"
            formatDesc = "Unix ve sunucu standardı. Çok çekirdekli iş parçacıklarıyla yüksek hızda arşivleme sağlar."
            formatCompScore = 0.72
            formatSpeedScore = 0.92

        case .zip:
            formatMultiplier = 1.0
            baseThroughputMBps = 320.0
            formatBadge = "🌐 Evrensel Standart"
            formatDesc = "macOS, Windows, iOS ve Android'de harici araç gerektirmeden açılır. En uyumlu formattır."
            formatCompScore = 0.65
            formatSpeedScore = 0.85

        case .tarBz2:
            formatMultiplier = 0.85
            baseThroughputMBps = 140.0
            formatBadge = "📚 Bzip2 Derin Sıkıştırma"
            formatDesc = "Metin, kod ve veritabanı dökümlerinde ZIP'e göre %20-30 daha küçük arşiv üretir."
            formatCompScore = 0.85
            formatSpeedScore = 0.55

        case .tarXz:
            formatMultiplier = 0.78
            baseThroughputMBps = 65.0
            formatBadge = "💎 Maksimum LZMA2"
            formatDesc = "En küçük arşiv boyutu için gelişmiş LZMA algoritması. İşlem süresi daha uzundur."
            formatCompScore = 0.98
            formatSpeedScore = 0.35

        case .sevenZip:
            formatMultiplier = 0.80
            baseThroughputMBps = 80.0
            formatBadge = "🗜️ 7-Zip LZMA"
            formatDesc = "Modern ve yüksek verimli sıkıştırma mimarisi."
            formatCompScore = 0.94
            formatSpeedScore = 0.45

        default:
            formatMultiplier = 1.0
            baseThroughputMBps = 300.0
            formatBadge = "Standart Arşiv"
            formatDesc = "Genel amaçlı arşiv formatı."
            formatCompScore = 0.60
            formatSpeedScore = 0.70
        }

        // TAR durumunda sıkıştırma yoktur (seviye ne olursa olsun boyut değişmez)
        let clampedCompressed: Int64
        let savings: Double

        if format == .tar || level == .store {
            clampedCompressed = totalSize
            savings = 0.0
            formatCompScore = 0.02
        } else {
            // Gerçekçi boyut modeli:
            // - Medya/Zaten sıkışık: ~%98 (neredeyse hiç küçülmez)
            // - Metin/Kod: format ve seviyeye göre %15 - %45 aralığına iner
            // - Diğer ikililer: format ve seviyeye göre %40 - %75 aralığına iner
            let estAlready = Double(stats.alreadyCompressedBytes) * 0.98
            let estHighly = Double(stats.highlyCompressibleBytes) * max(0.12, 0.38 * levelMultiplier * formatMultiplier)
            let estRegular = Double(stats.regularBytes) * max(0.38, 0.72 * levelMultiplier * formatMultiplier)

            let totalEst = Int64(estAlready + estHighly + estRegular)
            clampedCompressed = min(totalSize, max(128, totalEst))
            savings = (1.0 - (Double(clampedCompressed) / Double(totalSize))) * 100.0
        }

        // Hız & Süre hesaplaması (Apple Silicon throughput)
        let actualThroughputMBps = max(20.0, baseThroughputMBps * speedMultiplier)
        let totalMB = Double(totalSize) / (1024.0 * 1024.0)
        let estSeconds = max(0.05, totalMB / actualThroughputMBps)

        // Hız etiketi
        let speedLabelText: String
        if estSeconds < 0.3 {
            speedLabelText = "Işık Hızı (~0.2 sn)"
        } else if estSeconds < 1.0 {
            speedLabelText = "Çok Hızlı (~\(String(format: "%.1f", estSeconds)) sn)"
        } else if estSeconds < 5.0 {
            speedLabelText = "Seri (~\(String(format: "%.1f", estSeconds)) sn)"
        } else if estSeconds < 15.0 {
            speedLabelText = "Orta Hız (~\(String(format: "%.1f", estSeconds)) sn)"
        } else {
            speedLabelText = "Derin Analiz (~\(String(format: "%.0f", estSeconds)) sn)"
        }

        // Hız & Verim Skorları (0.0 ... 1.0)
        let finalSpeedScore = min(1.0, max(0.1, formatSpeedScore * speedMultiplier))
        let finalCompScore = min(1.0, max(0.02, formatCompScore * max(0.2, (savings / 100.0) * 1.35)))

        return SimulationResult(
            originalTotalSize: totalSize,
            estimatedCompressedSize: clampedCompressed,
            savingsPercentage: max(0.0, min(savings, 96.0)),
            estimatedDurationSeconds: estSeconds,
            mediaRatio: Double(stats.alreadyCompressedBytes) / Double(totalSize),
            compressibleRatio: Double(stats.highlyCompressibleBytes) / Double(totalSize),
            regularRatio: Double(stats.regularBytes) / Double(totalSize),
            speedScore: finalSpeedScore,
            compressionScore: finalCompScore,
            speedLabel: speedLabelText,
            formatBadge: formatBadge,
            formatDescription: formatDesc,
            levelDescription: levelDesc,
            isSampleReference: stats.isSampleReference,
            fileCount: stats.fileCount
        )
    }

    /// Geriye dönük uyumluluk için tek fonksiyonlu simülasyon
    public func simulate(
        sourceURLs: [URL],
        format: ArchiveFormat,
        level: CompressionLevel
    ) -> SimulationResult {
        let stats = analyzeSources(urls: sourceURLs)
        return simulate(stats: stats, format: format, level: level)
    }

    // MARK: - Dosya İnceleme ve Sınıflandırma

    private func analyzeItem(
        at url: URL,
        totalSize: inout Int64,
        highly: inout Int64,
        already: inout Int64,
        regular: inout Int64,
        fileCount: inout Int
    ) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }

        if isDir.boolValue {
            if let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                       vals.isRegularFile == true,
                       let sz = vals.fileSize {
                        fileCount += 1
                        categorize(ext: fileURL.pathExtension.lowercased(), size: Int64(sz), totalSize: &totalSize, highly: &highly, already: &already, regular: &regular)
                    }
                }
            }
        } else {
            let sz = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            fileCount += 1
            categorize(ext: url.pathExtension.lowercased(), size: sz, totalSize: &totalSize, highly: &highly, already: &already, regular: &regular)
        }
    }

    private func categorize(
        ext: String,
        size: Int64,
        totalSize: inout Int64,
        highly: inout Int64,
        already: inout Int64,
        regular: inout Int64
    ) {
        totalSize += size

        switch ext {
        case "txt", "log", "json", "xml", "csv", "html", "css", "js", "ts", "swift", "c", "cpp", "h", "py", "md", "sql", "yaml", "yml", "pdf", "docx", "xlsx":
            highly += size
        case "jpg", "jpeg", "png", "webp", "heic", "gif", "mp4", "mov", "mkv", "avi", "mp3", "aac", "zip", "rar", "7z", "gz", "bz2", "xz", "dmg", "iso":
            already += size
        default:
            regular += size
        }
    }
}
