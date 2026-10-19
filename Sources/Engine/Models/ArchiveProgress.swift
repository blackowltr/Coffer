import Foundation

/// Arşivleme ve çıkarma işlemleri sırasında yayınlanan canlı ilerleme modeli
public struct ArchiveProgress: Sendable {
    public let fractionCompleted: Double   // 0.0 ... 1.0
    public let currentFilename: String     // Anlık işlenen dosya adı
    public let processedBytes: Int64       // Şimdiye kadar işlenen byte
    public let totalBytes: Int64           // Toplam işlenecek byte
    public let speedBytesPerSecond: Double // Anlık transfer/işlem hızı
    public let estimatedRemainingTime: TimeInterval? // Kalan tahmini süre (saniye)
    public let elapsedTime: TimeInterval   // Geçen süre (saniye)
    public let processedLog: [String]      // İşlenen dosyaların kayıt günlüğü

    public init(
        fractionCompleted: Double,
        currentFilename: String,
        processedBytes: Int64,
        totalBytes: Int64,
        speedBytesPerSecond: Double = 0.0,
        estimatedRemainingTime: TimeInterval? = nil,
        elapsedTime: TimeInterval = 0.0,
        processedLog: [String] = []
    ) {
        self.fractionCompleted = max(0.0, min(fractionCompleted, 1.0))
        self.currentFilename = currentFilename
        self.processedBytes = processedBytes
        self.totalBytes = max(1, totalBytes)
        self.speedBytesPerSecond = speedBytesPerSecond
        self.estimatedRemainingTime = estimatedRemainingTime
        self.elapsedTime = elapsedTime
        self.processedLog = processedLog
    }

    /// Yüzde metni ("%78.4")
    public var percentageString: String {
        String(format: "%%%0.1f", fractionCompleted * 100)
    }

    /// Okunabilir hız metni ("34.5 MB/s")
    public var formattedSpeed: String {
        guard speedBytesPerSecond > 0 else { return "-- MB/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(speedBytesPerSecond), countStyle: .file) + "/s"
    }

    /// Okunabilir geçen süre metni ("12 sn" veya "01:25")
    public var formattedElapsedTime: String {
        guard elapsedTime > 0 else { return "0 sn" }
        let seconds = Int(elapsedTime) % 60
        let minutes = (Int(elapsedTime) / 60) % 60
        let hours = Int(elapsedTime) / 3600

        if hours > 0 {
            return String(format: "%d sa %d dk", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d dk %d sn", minutes, seconds)
        } else {
            return String(format: "%d sn", seconds)
        }
    }

    /// Okunabilir kalan süre metni ("Kalan: 12 sn")
    public var formattedRemainingTime: String {
        guard let remaining = estimatedRemainingTime, remaining > 0, remaining < 3600 * 24 else {
            return "Hesaplanıyor..."
        }
        let seconds = Int(remaining) % 60
        let minutes = (Int(remaining) / 60) % 60
        let hours = Int(remaining) / 3600

        if hours > 0 {
            return String(format: "%d sa %d dk", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d dk %d sn", minutes, seconds)
        } else {
            return String(format: "%d sn", seconds)
        }
    }

    /// Okunabilir işlenen boyut ("45.2 MB")
    public var formattedProcessedBytes: String {
        ByteCountFormatter.string(fromByteCount: processedBytes, countStyle: .file)
    }

    /// Okunabilir toplam boyut ("120.0 MB")
    public var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}
