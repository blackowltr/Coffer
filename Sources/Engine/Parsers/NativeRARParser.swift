import Foundation

/// Apple Silicon Native RAR4 & RAR5 Arşiv Ayrıştırıcısı
/// Harici kütüphane gerektirmeden dosya başlıklarını, CRC, boyut ve şifreleme durumunu okur.
public final class NativeRARParser: Sendable {

    public init() {}

    /// Verilen URL'deki RAR arşivini ayrıştırıp dosya listesini döner
    public func parseArchive(at url: URL) throws -> (items: [ArchiveItem], metadata: ArchiveMetadata) {
        let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
        guard fileData.count >= 7 else {
            throw RARParserError.corruptedArchive("Dosya çok küçük veya geçersiz.")
        }

        let magicRAR4: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]
        let magicRAR5: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]

        if fileData.starts(with: magicRAR5) {
            return try parseRAR5(data: fileData, url: url)
        } else if fileData.starts(with: magicRAR4) {
            return try parseRAR4(data: fileData, url: url)
        } else {
            throw RARParserError.unsupportedFormat("Geçersiz RAR sihirli byte imzası.")
        }
    }

    // MARK: - RAR 5.0 Format Parser

    private func parseRAR5(data: Data, url: URL) throws -> (items: [ArchiveItem], metadata: ArchiveMetadata) {
        var offset = 8 // RAR5 Magic bytes (8 bytes)
        var items: [ArchiveItem] = []
        var isEncrypted = false
        var isMultiVolume = false
        var hasRecoveryRecord = false
        var totalUncompressed: Int64 = 0

        while offset < data.count {
            guard offset + 4 <= data.count else { break }

            // Header CRC32 (4 bytes)
            let _ = data.readUInt32LE(at: offset)
            offset += 4

            // Header Size (VINT)
            guard let (headerSize, vintLen) = data.readVInt(at: offset) else { break }
            offset += vintLen
            let headerDataEnd = offset + Int(headerSize)
            guard headerDataEnd <= data.count else { break }

            // Header Type (VINT)
            guard let (headerType, typeVintLen) = data.readVInt(at: offset) else { break }
            offset += typeVintLen

            // Header Flags (VINT)
            guard let (headerFlags, flagsVintLen) = data.readVInt(at: offset) else { break }
            offset += flagsVintLen

            var extraAreaSize: UInt64 = 0
            if (headerFlags & 0x0001) != 0 {
                if let (extraSize, extraVintLen) = data.readVInt(at: offset) {
                    extraAreaSize = extraSize
                    offset += extraVintLen
                }
            }

            var dataSize: UInt64 = 0
            if (headerFlags & 0x0002) != 0 {
                if let (dSize, dataVintLen) = data.readVInt(at: offset) {
                    dataSize = dSize
                    offset += dataVintLen
                }
            }

            // Blok Tipleri:
            // 1: Main Archive Header
            // 2: File Header
            // 3: Service Header (örn: Recovery Record)
            // 4: Encryption Header
            // 5: End of Archive
            switch headerType {
            case 1: // Main Header
                if (headerFlags & 0x0001) != 0 {
                    isMultiVolume = true
                }
            case 2: // File Header
                if let item = parseRAR5FileHeader(
                    data: data,
                    offset: offset,
                    headerEnd: headerDataEnd - Int(extraAreaSize),
                    dataSize: Int64(dataSize)
                ) {
                    items.append(item)
                    totalUncompressed += item.uncompressedSize
                    if item.isEncrypted { isEncrypted = true }
                }
            case 3: // Service Header
                hasRecoveryRecord = true
            case 4: // Encryption Header
                isEncrypted = true
            default:
                break
            }

            offset = headerDataEnd + Int(dataSize)
        }

        let dirCount = items.filter { $0.isDirectory }.count
        let fileCount = items.count - dirCount

        let metadata = ArchiveMetadata(
            format: .rar,
            archiveURL: url,
            totalFileCount: fileCount,
            totalDirectoryCount: dirCount,
            totalUncompressedSize: totalUncompressed,
            archiveFileSize: Int64(data.count),
            isEncrypted: isEncrypted,
            isMultiVolume: isMultiVolume,
            hasRecoveryRecord: hasRecoveryRecord,
            recoveryRecordPercentage: hasRecoveryRecord ? 3.0 : nil
        )

        return (items, metadata)
    }

    private func parseRAR5FileHeader(
        data: Data,
        offset: Int,
        headerEnd: Int,
        dataSize: Int64
    ) -> ArchiveItem? {
        var cur = offset

        // File Flags (VINT)
        guard let (fileFlags, vintLen) = data.readVInt(at: cur) else { return nil }
        cur += vintLen

        let isDirectory = (fileFlags & 0x0001) != 0

        // Uncompressed Size (VINT)
        guard let (unpSize, unpLen) = data.readVInt(at: cur) else { return nil }
        cur += unpLen

        // Attributes (VINT)
        guard let (_, attrLen) = data.readVInt(at: cur) else { return nil }
        cur += attrLen

        // Optional Modification Time
        var modDate: Date? = nil
        if (fileFlags & 0x0002) != 0 {
            let mtime = data.readUInt32LE(at: cur)
            cur += 4
            modDate = Date(timeIntervalSince1970: TimeInterval(mtime))
        }

        // Optional CRC32
        var crcString: String? = nil
        if (fileFlags & 0x0004) != 0 {
            let crc = data.readUInt32LE(at: cur)
            cur += 4
            crcString = String(format: "%08X", crc)
        }

        // File Name Length (VINT)
        guard let (nameLen, nameVintLen) = data.readVInt(at: cur) else { return nil }
        cur += nameVintLen

        guard cur + Int(nameLen) <= data.count else { return nil }
        let nameData = data.subdata(in: cur..<(cur + Int(nameLen)))
        let filename = String(data: nameData, encoding: .utf8) ?? String(decoding: nameData, as: UTF8.self)

        let isEncrypted = (fileFlags & 0x0004) != 0 && (fileFlags & 0x0400) != 0

        return ArchiveItem(
            path: filename,
            uncompressedSize: Int64(unpSize),
            compressedSize: dataSize,
            modificationDate: modDate,
            isDirectory: isDirectory,
            isEncrypted: isEncrypted,
            crc32: crcString
        )
    }

    // MARK: - RAR 4.0 Format Parser

    private func parseRAR4(data: Data, url: URL) throws -> (items: [ArchiveItem], metadata: ArchiveMetadata) {
        var offset = 7 // RAR4 Magic: 0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00
        var items: [ArchiveItem] = []
        var isEncrypted = false
        var isMultiVolume = false
        var hasRecoveryRecord = false
        var totalUncompressed: Int64 = 0

        while offset + 7 <= data.count {
            let _ = data.readUInt16LE(at: offset)     // Head CRC (2 bytes)
            let headType = data[offset + 2]           // Head Type (1 byte)
            let headFlags = data.readUInt16LE(at: offset + 3) // Flags (2 bytes)
            var headSize = Int(data.readUInt16LE(at: offset + 5)) // Head Size (2 bytes)

            if (headFlags & 0x8000) != 0 { // ADD_SIZE bayrağı
                guard offset + 11 <= data.count else { break }
                let addSize = data.readUInt32LE(at: offset + 7)
                headSize += Int(addSize)
            }

            guard headSize >= 7, offset + headSize <= data.count else { break }

            switch headType {
            case 0x73: // Main Archive Header
                if (headFlags & 0x0001) != 0 {
                    isMultiVolume = true
                }
                if (headFlags & 0x0080) != 0 {
                    isEncrypted = true
                }
            case 0x74: // File Header
                if let item = parseRAR4FileHeader(data: data, offset: offset, headFlags: headFlags) {
                    items.append(item)
                    totalUncompressed += item.uncompressedSize
                    if item.isEncrypted { isEncrypted = true }
                }
            case 0x7A: // Recovery Record
                hasRecoveryRecord = true
            case 0x7B: // End of archive
                break
            default:
                break
            }

            offset += headSize
        }

        let dirCount = items.filter { $0.isDirectory }.count
        let fileCount = items.count - dirCount

        let metadata = ArchiveMetadata(
            format: .rar,
            archiveURL: url,
            totalFileCount: fileCount,
            totalDirectoryCount: dirCount,
            totalUncompressedSize: totalUncompressed,
            archiveFileSize: Int64(data.count),
            isEncrypted: isEncrypted,
            isMultiVolume: isMultiVolume,
            hasRecoveryRecord: hasRecoveryRecord,
            recoveryRecordPercentage: hasRecoveryRecord ? 3.0 : nil
        )

        return (items, metadata)
    }

    private func parseRAR4FileHeader(data: Data, offset: Int, headFlags: UInt16) -> ArchiveItem? {
        guard offset + 32 <= data.count else { return nil }

        let packSize = data.readUInt32LE(at: offset + 7)
        let unpSize = data.readUInt32LE(at: offset + 11)
        let fileCRC = data.readUInt32LE(at: offset + 16)
        let fileTime = data.readUInt32LE(at: offset + 20)
        let nameSize = Int(data.readUInt16LE(at: offset + 26))
        let fileAttr = data.readUInt32LE(at: offset + 28)

        var cur = offset + 32
        var highPackSize: UInt64 = 0
        var highUnpSize: UInt64 = 0

        // 64-bit boyut bayrağı
        if (headFlags & 0x0100) != 0 {
            guard cur + 8 <= data.count else { return nil }
            highPackSize = UInt64(data.readUInt32LE(at: cur))
            highUnpSize = UInt64(data.readUInt32LE(at: cur + 4))
            cur += 8
        }

        guard cur + nameSize <= data.count else { return nil }
        let nameData = data.subdata(in: cur..<(cur + nameSize))
        cur += nameSize

        // Dosya adı çözme
        let filename = String(data: nameData, encoding: .utf8)
            ?? String(data: nameData, encoding: .windowsCP1254) // Türkçe Windows desteği
            ?? String(decoding: nameData, as: UTF8.self)

        let isDirectory = (fileAttr & 0x10) != 0 || (headFlags & 0x00E0) == 0x00E0
        let isEncrypted = (headFlags & 0x0004) != 0

        let totalPack = (highPackSize << 32) | UInt64(packSize)
        let totalUnp = (highUnpSize << 32) | UInt64(unpSize)

        // DOS tarihini Date nesnesine dönüştürme
        let modDate = parseDosDateTime(fileTime)
        let crcString = String(format: "%08X", fileCRC)

        return ArchiveItem(
            path: filename,
            uncompressedSize: Int64(totalUnp),
            compressedSize: Int64(totalPack),
            modificationDate: modDate,
            isDirectory: isDirectory,
            isEncrypted: isEncrypted,
            crc32: crcString
        )
    }

    private func parseDosDateTime(_ dosTime: UInt32) -> Date? {
        let time = dosTime & 0xFFFF
        let date = (dosTime >> 16) & 0xFFFF

        let seconds = Int((time & 0x1F) * 2)
        let minutes = Int((time >> 5) & 0x3F)
        let hours = Int((time >> 11) & 0x1F)

        let day = Int(date & 0x1F)
        let month = Int((date >> 5) & 0x0F)
        let year = Int(((date >> 9) & 0x7F) + 1980)

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hours
        comps.minute = minutes
        comps.second = seconds
        return Calendar.current.date(from: comps)
    }
}

// MARK: - Binary Helper Extensions

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    /// RAR5 Değişken Uzunluklu Tamsayı (Variable-Length Integer - VINT) okuyucu
    func readVInt(at offset: Int) -> (value: UInt64, length: Int)? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var i = 0

        while offset + i < count && i < 10 {
            let byte = self[offset + i]
            value |= UInt64(byte & 0x7F) << shift
            i += 1
            if (byte & 0x80) == 0 {
                return (value, i)
            }
            shift += 7
        }
        return nil
    }
}

public enum RARParserError: LocalizedError {
    case corruptedArchive(String)
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .corruptedArchive(let msg): return "Bozuk RAR Arşivi: \(msg)"
        case .unsupportedFormat(let msg): return "Desteklenmeyen Biçim: \(msg)"
        }
    }
}
