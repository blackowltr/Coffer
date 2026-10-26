import Foundation

/// Çıkarma öncesi disk alanı gereksinimlerini ve tasarruf potansiyelini analiz eden rapor modeli
public struct SpaceRequirementReport: Sendable, Equatable {
    public let availableDiskBytes: Int64
    public let archiveFileBytes: Int64
    public let totalUncompressedBytes: Int64
    public let largestItemBytes: Int64
    public let standardRequiredBytes: Int64
    public let spaceSaverRequiredBytes: Int64
    public let isLowDiskSpace: Bool
    public let canExtractStandard: Bool
    public let canExtractSpaceSaver: Bool
    public let savedDiskSpaceBytes: Int64
    public let isAPFS: Bool

    // MARK: - Formatlanmış Gösterim Yardımcıları

    public var availableDiskFormatted: String {
        ByteCountFormatter.string(fromByteCount: availableDiskBytes, countStyle: .file)
    }

    public var archiveFileFormatted: String {
        ByteCountFormatter.string(fromByteCount: archiveFileBytes, countStyle: .file)
    }

    public var totalUncompressedFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalUncompressedBytes, countStyle: .file)
    }

    public var standardRequiredFormatted: String {
        ByteCountFormatter.string(fromByteCount: standardRequiredBytes, countStyle: .file)
    }

    public var spaceSaverRequiredFormatted: String {
        ByteCountFormatter.string(fromByteCount: spaceSaverRequiredBytes, countStyle: .file)
    }

    public var savedDiskSpaceFormatted: String {
        ByteCountFormatter.string(fromByteCount: savedDiskSpaceBytes, countStyle: .file)
    }

    public var statusBadgeText: String {
        if !canExtractStandard && canExtractSpaceSaver {
            return "⚡ Alan Açma Modu Gerekli (Düşük Disk Alanı)"
        } else if isLowDiskSpace {
            return "⚠️ Disk Alanı Kritik (Alan Açma Önerilir)"
        } else {
            return "✓ Disk Alanı Yeterli"
        }
    }

    public var statusBadgeColorName: String {
        if !canExtractStandard && canExtractSpaceSaver {
            return "orange"
        } else if isLowDiskSpace {
            return "yellow"
        } else {
            return "green"
        }
    }

    public var recommendationDescription: String {
        if !canExtractStandard && canExtractSpaceSaver {
            return "Hedef diskte standart çıkarma için gereken \(standardRequiredFormatted) boş alan yok. Alan Açarak Çıkarma (Space-Saver) modu sayesinde yalnızca \(spaceSaverRequiredFormatted) boş alanla çıkarma sorunsuzca tamamlanabilir."
        } else if isLowDiskSpace {
            return "Mevcut boş alan (\(availableDiskFormatted)) standart çıkarma sınırına çok yakın. Alan Açarak Çıkarma modu etkinleştirilirse sistem diski şişmeden güvenle tamamlanır."
        } else {
            return "Hedef diskte yeterli alan bulunmaktadır (\(availableDiskFormatted) boş). Dilerseniz büyük arşivlerde tepe alan kullanımını düşürmek için Alan Açma Modunu kullanabilirsiniz."
        }
    }
}

/// Önceden Alan Kontrolü (Pre-flight Space Check) Simülatörü
public final class SpaceRequirementEstimator: Sendable {
    public static let shared = SpaceRequirementEstimator()

    private init() {}

    /// Belirtilen URL'nin bulunduğu birimdeki kullanılabilir boş alanı sorgular
    public func availableCapacity(for url: URL) -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            if let importantCap = values.volumeAvailableCapacityForImportantUsage, importantCap > 0 {
                return importantCap
            }
            if let basicCap = values.volumeAvailableCapacity, basicCap > 0 {
                return Int64(basicCap)
            }
        } catch {
            // Hata durumunda statfs ile dene
            var stat = statfs()
            if statfs(url.path, &stat) == 0 {
                return Int64(stat.f_bavail) * Int64(stat.f_bsize)
            }
        }
        return 0
    }

    /// Çıkarma öncesinde disk alanı gereksinimlerini ve kazancını simüle eder
    public func evaluate(
        archiveURL: URL,
        destinationURL: URL,
        items: [ArchiveItem],
        safetyMarginBytes: Int64 = 512 * 1024 * 1024 // 512 MB tampon payı
    ) -> SpaceRequirementReport {
        let archiveSize = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64) ?? 0
        let totalUncompressed = items.reduce(0) { $0 + $1.uncompressedSize }
        let largestItem = items.map(\.uncompressedSize).max() ?? 0

        let available = availableCapacity(for: destinationURL)
        let isAPFS = APFSPunchHole.isAPFS(at: destinationURL)

        // Standart çıkarma: Arşivin açılmış halinin tamamı + güvenlik marjı
        let standardRequired = totalUncompressed + (safetyMarginBytes / 2)

        // Space-Saver modu tepe ihtiyacı: En büyük tek dosya + güvenlik tamponu
        let peakUnit = max(largestItem, 256 * 1024 * 1024)
        let spaceSaverRequired = peakUnit + safetyMarginBytes

        let isLowSpace = available < (standardRequired + safetyMarginBytes)
        let canStandard = available >= standardRequired
        let canSpaceSaver = available >= spaceSaverRequired
        let savedBytes = max(0, standardRequired - spaceSaverRequired)

        return SpaceRequirementReport(
            availableDiskBytes: available,
            archiveFileBytes: archiveSize,
            totalUncompressedBytes: totalUncompressed,
            largestItemBytes: largestItem,
            standardRequiredBytes: standardRequired,
            spaceSaverRequiredBytes: spaceSaverRequired,
            isLowDiskSpace: isLowSpace,
            canExtractStandard: canStandard,
            canExtractSpaceSaver: canSpaceSaver,
            savedDiskSpaceBytes: savedBytes,
            isAPFS: isAPFS
        )
    }
}
