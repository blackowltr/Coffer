import Foundation

/// Arşiv genel özellikleri, başlık bilgileri ve istatistikleri
public struct ArchiveMetadata: Sendable {
    public let format: ArchiveFormat
    public let archiveURL: URL
    public let totalFileCount: Int
    public let totalDirectoryCount: Int
    public let totalUncompressedSize: Int64
    public let archiveFileSize: Int64
    public let isEncrypted: Bool
    public let hasEncryptedHeaders: Bool
    public let isSolid: Bool
    public let isMultiVolume: Bool
    public let volumeCount: Int
    public let hasRecoveryRecord: Bool
    public let recoveryRecordPercentage: Double?
    public let comment: String?

    public init(
        format: ArchiveFormat,
        archiveURL: URL,
        totalFileCount: Int,
        totalDirectoryCount: Int,
        totalUncompressedSize: Int64,
        archiveFileSize: Int64,
        isEncrypted: Bool = false,
        hasEncryptedHeaders: Bool = false,
        isSolid: Bool = false,
        isMultiVolume: Bool = false,
        volumeCount: Int = 1,
        hasRecoveryRecord: Bool = false,
        recoveryRecordPercentage: Double? = nil,
        comment: String? = nil
    ) {
        self.format = format
        self.archiveURL = archiveURL
        self.totalFileCount = totalFileCount
        self.totalDirectoryCount = totalDirectoryCount
        self.totalUncompressedSize = totalUncompressedSize
        self.archiveFileSize = archiveFileSize
        self.isEncrypted = isEncrypted
        self.hasEncryptedHeaders = hasEncryptedHeaders
        self.isSolid = isSolid
        self.isMultiVolume = isMultiVolume
        self.volumeCount = volumeCount
        self.hasRecoveryRecord = hasRecoveryRecord
        self.recoveryRecordPercentage = recoveryRecordPercentage
        self.comment = comment
    }

    /// Genel sıkıştırma tasarruf oranı (%)
    public var overallSavingsRatio: Double {
        guard totalUncompressedSize > 0 else { return 0.0 }
        let ratio = (1.0 - (Double(archiveFileSize) / Double(totalUncompressedSize))) * 100.0
        return max(0.0, min(ratio, 99.9))
    }

    public var formattedArchiveSize: String {
        ByteCountFormatter.string(fromByteCount: archiveFileSize, countStyle: .file)
    }

    public var formattedUncompressedSize: String {
        ByteCountFormatter.string(fromByteCount: totalUncompressedSize, countStyle: .file)
    }
}

/// Arşiv bütünlük testi sonucu
public struct ArchiveTestResult: Sendable {
    public let isSuccess: Bool
    public let totalItemsChecked: Int
    public let errors: [String]
    public let duration: TimeInterval

    public init(isSuccess: Bool, totalItemsChecked: Int, errors: [String] = [], duration: TimeInterval = 0) {
        self.isSuccess = isSuccess
        self.totalItemsChecked = totalItemsChecked
        self.errors = errors
        self.duration = duration
    }
}
