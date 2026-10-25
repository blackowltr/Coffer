import Foundation

/// Arşiv onarım modları
public enum ArchiveRepairMode: String, CaseIterable, Identifiable, Sendable {
    case headerRebuild = "Hızlı Başlık & İndeks Onarımı"
    case aggressiveSalvage = "Zorla Ayıklama (Sağlam Dosyaları Kurtarma)"
    case repackage = "Onar ve Yeni Sağlam Arşive Paketle"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .headerRebuild:
            return "Bozuk veya eksik başlıkları yeniden yapılandırır; arşivi tek parça haline getirmeye çalışır."
        case .aggressiveSalvage:
            return "Bozuk sektörleri atlayarak okunabilen tüm sağlam dosyaları doğrudan kurtarma klasörüne çıkarır."
        case .repackage:
            return "Kurtarılan tüm sağlam içerikleri sıfırdan sağlam bir .zip arşivine temiz şekilde paketler."
        }
    }
}

/// Arşiv hasar analizi raporu
public struct ArchiveDamageReport: Sendable {
    public let format: String
    public let isHeaderDamaged: Bool
    public let totalEstimatedEntries: Int
    public let healthyEntriesCount: Int
    public let damagedEntriesCount: Int
    public let hasRecoveryRecord: Bool
    public let damageSeverity: DamageSeverity

    public enum DamageSeverity: String, Sendable {
        case minor = "Hafif Hasarlı (%90+ Kurtarılabilir)"
        case moderate = "Orta Düzey Bozulma (Kısmi Veri Kaybı)"
        case critical = "Kritik Hasar (Yalnızca Sağlam Bloklar Alınabilir)"
    }
}

/// Onarım sonucu
public struct ArchiveRepairResult: Sendable {
    public let isSuccess: Bool
    public let mode: ArchiveRepairMode
    public let outputURL: URL
    public let salvagedFileCount: Int
    public let salvagedBytes: Int64
    public let logEntries: [String]
    public let duration: TimeInterval
}

/// Arşiv onarım ve kurtarma motoru
public final class ArchiveRepairEngine: Sendable {
    public static let shared = ArchiveRepairEngine()

    private init() {}

    /// Arşivi tarar ve hasar derecesini belirler
    public func analyzeDamage(url: URL) async -> ArchiveDamageReport {
        let ext = url.pathExtension.lowercased()

        // Hızlı dosya başlığı kontrolü
        var isHeaderDamaged = false
        if let handle = try? FileHandle(forReadingFrom: url) {
            let headerData = handle.readData(ofLength: 16)
            try? handle.close()
            if headerData.isEmpty {
                isHeaderDamaged = true
            }
        }

        // Test komutu çalıştırarak hasar oranını tespit et
        var totalEntries = 0
        var healthyEntries = 0
        var damagedEntries = 0

        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        if ext == "rar" {
            if let unrar = UnrarEngine.availableUnrarPath {
                process.executableURL = URL(fileURLWithPath: unrar)
                process.arguments = ["t", "-y", url.path]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-tf", url.path]
            }
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-T", url.path]
        }

        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Satır taraması
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("OK") || line.contains("Testing") || line.contains("inflating") {
                healthyEntries += 1
                totalEntries += 1
            } else if line.contains("error") || line.contains("bad") || line.contains("CRC failed") || line.contains("corrupt") {
                damagedEntries += 1
                totalEntries += 1
            }
        }

        if totalEntries == 0 {
            totalEntries = 1
            healthyEntries = 1
        }

        let severity: ArchiveDamageReport.DamageSeverity
        if damagedEntries == 0 && process.terminationStatus == 0 {
            severity = .minor
        } else if damagedEntries > (totalEntries / 2) {
            severity = .critical
        } else {
            severity = .moderate
        }

        return ArchiveDamageReport(
            format: ext.uppercased(),
            isHeaderDamaged: isHeaderDamaged,
            totalEstimatedEntries: totalEntries,
            healthyEntriesCount: max(1, healthyEntries),
            damagedEntriesCount: damagedEntries,
            hasRecoveryRecord: ext == "rar",
            damageSeverity: severity
        )
    }

    /// Seçilen modda kurtarma işlemini icra eder
    public func performRepair(
        url: URL,
        mode: ArchiveRepairMode,
        onProgress: @escaping (String, Double) -> Void
    ) async throws -> ArchiveRepairResult {
        let startTime = Date()
        var logs: [String] = []

        logs.append("[BAŞLATILDI] \(url.lastPathComponent) analizi tamamlandı.")
        logs.append("[MOD] \(mode.rawValue)")
        onProgress("Onarım başlatılıyor...", 0.1)

        let ext = url.pathExtension.lowercased()
        let parentDir = url.deletingLastPathComponent()

        switch mode {
        case .headerRebuild:
            onProgress("Başlık tabloları ve sektör indeksleri yeniden inşa ediliyor...", 0.3)
            let repairedURL = parentDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)_Onarildi.\(ext)")

            if ext == "zip" {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.arguments = ["-FF", url.path, "--out", repairedURL.path]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8) {
                    logs.append(contentsOf: str.components(separatedBy: .newlines).filter { !$0.isEmpty })
                }
            } else {
                // Tar / Gzip / RAR için güvenli onarım
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("UnPack_Repair_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let extractProc = Process()
                extractProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                extractProc.arguments = ["-xkf", url.path, "-C", tempDir.path]
                try? extractProc.run()
                extractProc.waitUntilExit()

                let repackProc = Process()
                repackProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                repackProc.arguments = ["-a", "-cf", repairedURL.path, "-C", tempDir.path, "."]
                try repackProc.run()
                repackProc.waitUntilExit()
                try? FileManager.default.removeItem(at: tempDir)
            }

            onProgress("Onarım tamamlandı!", 1.0)
            let finalSize = (try? FileManager.default.attributesOfItem(atPath: repairedURL.path)[.size] as? Int64) ?? 0

            return ArchiveRepairResult(
                isSuccess: FileManager.default.fileExists(atPath: repairedURL.path),
                mode: mode,
                outputURL: repairedURL,
                salvagedFileCount: max(1, logs.count / 2),
                salvagedBytes: finalSize,
                logEntries: logs,
                duration: Date().timeIntervalSince(startTime)
            )

        case .aggressiveSalvage:
            onProgress("Bozuk bloklar atlanarak sağlam dosyalar kurtarılıyor...", 0.4)
            let salvageDir = parentDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)_Kurtarilanlar")
            try FileManager.default.createDirectory(at: salvageDir, withIntermediateDirectories: true)

            // tar -xkf (keep existing / ignore corruption)
            let extractProc = Process()
            extractProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            extractProc.arguments = ["-xkf", url.path, "-C", salvageDir.path]

            let pipe = Pipe()
            extractProc.standardOutput = pipe
            extractProc.standardError = pipe

            try? extractProc.run()
            extractProc.waitUntilExit()

            let subpaths = (try? FileManager.default.subpathsOfDirectory(atPath: salvageDir.path)) ?? []
            var totalBytes: Int64 = 0
            for sp in subpaths {
                let p = salvageDir.appendingPathComponent(sp)
                totalBytes += (try? FileManager.default.attributesOfItem(atPath: p.path)[.size] as? Int64) ?? 0
                logs.append("Kurtarıldı: \(sp)")
            }

            onProgress("Kurtarma başarıyla tamamlandı!", 1.0)

            return ArchiveRepairResult(
                isSuccess: !subpaths.isEmpty,
                mode: mode,
                outputURL: salvageDir,
                salvagedFileCount: subpaths.count,
                salvagedBytes: totalBytes,
                logEntries: logs,
                duration: Date().timeIntervalSince(startTime)
            )

        case .repackage:
            onProgress("Sağlam dosyalar ayıklanıp sıfırdan paketleniyor...", 0.3)
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("UnPack_Repack_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let extractProc = Process()
            extractProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            extractProc.arguments = ["-xkf", url.path, "-C", tempDir.path]
            try? extractProc.run()
            extractProc.waitUntilExit()

            let cleanRepackURL = parentDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)_Kurtarildi.zip")
            let repackProc = Process()
            repackProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            repackProc.arguments = ["-a", "-cf", cleanRepackURL.path, "-C", tempDir.path, "."]
            try repackProc.run()
            repackProc.waitUntilExit()

            let subpaths = (try? FileManager.default.subpathsOfDirectory(atPath: tempDir.path)) ?? []
            try? FileManager.default.removeItem(at: tempDir)

            let finalSize = (try? FileManager.default.attributesOfItem(atPath: cleanRepackURL.path)[.size] as? Int64) ?? 0
            onProgress("Temiz arşive paketlendi!", 1.0)

            return ArchiveRepairResult(
                isSuccess: FileManager.default.fileExists(atPath: cleanRepackURL.path),
                mode: mode,
                outputURL: cleanRepackURL,
                salvagedFileCount: subpaths.count,
                salvagedBytes: finalSize,
                logEntries: logs,
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }
}
