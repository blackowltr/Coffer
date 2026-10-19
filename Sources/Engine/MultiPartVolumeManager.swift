import Foundation

/// Çok parçalı (Multi-part / Split) arşivleri (.part1.rar, .7z.001, .z01 vb.) analiz eden ve yöneten motor
public struct MultiPartVolumeInfo: Equatable, Sendable {
    public let isMultiPart: Bool
    public let baseName: String
    public let currentPartIndex: Int
    public let allPartURLs: [URL]
    public let missingPartIndices: [Int]
    public let totalDetectedParts: Int
    public let totalByteSize: Int64

    public var isComplete: Bool {
        missingPartIndices.isEmpty && totalDetectedParts > 0
    }

    public var summaryDescription: String {
        if !isMultiPart { return "Tek parça standart arşiv" }
        if isComplete {
            let sizeStr = ByteCountFormatter.string(fromByteCount: totalByteSize, countStyle: .file)
            return "Çok Parçalı Arşiv: \(totalDetectedParts) parça mevcut (Toplam: \(sizeStr))"
        } else {
            let missingStr = missingPartIndices.map { "Part \($0)" }.joined(separator: ", ")
            return "Eksik Parça Tespit Edildi! (Eksikler: \(missingStr))"
        }
    }
}

public final class MultiPartVolumeManager: Sendable {
    public static let shared = MultiPartVolumeManager()

    private init() {}

    /// Verilen dosya URL'sinin çok parçalı bir arşivin parçası olup olmadığını analiz eder
    public func analyzeArchive(at fileURL: URL) -> MultiPartVolumeInfo {
        let filename = fileURL.lastPathComponent
        let parentDir = fileURL.deletingLastPathComponent()

        // 1. .part1.rar, .part01.rar, .part001.rar formatı
        let partRarRegex = try? NSRegularExpression(pattern: #"^(.*?)\.part(\d+)\.rar$"#, options: .caseInsensitive)
        if let match = partRarRegex?.firstMatch(in: filename, range: NSRange(location: 0, length: filename.utf16.count)) {
            if let baseRange = Range(match.range(at: 1), in: filename),
               let indexRange = Range(match.range(at: 2), in: filename),
               let currentIndex = Int(filename[indexRange]) {
                let baseName = String(filename[baseRange])
                return scanParts(baseName: baseName, parentDir: parentDir, currentIndex: currentIndex, patternType: .partRar)
            }
        }

        // 2. .7z.001, .7z.002 formatı
        let split7zRegex = try? NSRegularExpression(pattern: #"^(.*?)\.7z\.(\d+)$"#, options: .caseInsensitive)
        if let match = split7zRegex?.firstMatch(in: filename, range: NSRange(location: 0, length: filename.utf16.count)) {
            if let baseRange = Range(match.range(at: 1), in: filename),
               let indexRange = Range(match.range(at: 2), in: filename),
               let currentIndex = Int(filename[indexRange]) {
                let baseName = String(filename[baseRange])
                return scanParts(baseName: baseName, parentDir: parentDir, currentIndex: currentIndex, patternType: .split7z)
            }
        }

        // 3. .zip, .z01, .z02 formatı
        let splitZipRegex = try? NSRegularExpression(pattern: #"^(.*?)\.(z\d{2}|zip)$"#, options: .caseInsensitive)
        if let match = splitZipRegex?.firstMatch(in: filename, range: NSRange(location: 0, length: filename.utf16.count)) {
            if let baseRange = Range(match.range(at: 1), in: filename) {
                let baseName = String(filename[baseRange])
                let ext = fileURL.pathExtension.lowercased()
                let currentIndex: Int
                if ext == "zip" {
                    currentIndex = 1
                } else if ext.hasPrefix("z"), let num = Int(ext.dropFirst()) {
                    currentIndex = num
                } else {
                    currentIndex = 1
                }
                return scanParts(baseName: baseName, parentDir: parentDir, currentIndex: currentIndex, patternType: .splitZip)
            }
        }

        // Standart tek parça arşiv
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        return MultiPartVolumeInfo(
            isMultiPart: false,
            baseName: fileURL.deletingPathExtension().lastPathComponent,
            currentPartIndex: 1,
            allPartURLs: [fileURL],
            missingPartIndices: [],
            totalDetectedParts: 1,
            totalByteSize: size
        )
    }

    private enum PatternType {
        case partRar
        case split7z
        case splitZip
    }

    private func scanParts(baseName: String, parentDir: URL, currentIndex: Int, patternType: PatternType) -> MultiPartVolumeInfo {
        guard let files = try? FileManager.default.contentsOfDirectory(at: parentDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return MultiPartVolumeInfo(
                isMultiPart: true,
                baseName: baseName,
                currentPartIndex: currentIndex,
                allPartURLs: [],
                missingPartIndices: [],
                totalDetectedParts: 0,
                totalByteSize: 0
            )
        }

        var foundParts: [Int: URL] = [:]
        var totalSize: Int64 = 0

        for file in files {
            let name = file.lastPathComponent
            switch patternType {
            case .partRar:
                let regex = try? NSRegularExpression(pattern: #"^"# + NSRegularExpression.escapedPattern(for: baseName) + #"\.part(\d+)\.rar$"#, options: .caseInsensitive)
                if let match = regex?.firstMatch(in: name, range: NSRange(location: 0, length: name.utf16.count)),
                   let idxRange = Range(match.range(at: 1), in: name),
                   let idx = Int(name[idxRange]) {
                    foundParts[idx] = file
                    totalSize += (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                }
            case .split7z:
                let regex = try? NSRegularExpression(pattern: #"^"# + NSRegularExpression.escapedPattern(for: baseName) + #"\.7z\.(\d+)$"#, options: .caseInsensitive)
                if let match = regex?.firstMatch(in: name, range: NSRange(location: 0, length: name.utf16.count)),
                   let idxRange = Range(match.range(at: 1), in: name),
                   let idx = Int(name[idxRange]) {
                    foundParts[idx] = file
                    totalSize += (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                }
            case .splitZip:
                if name.lowercased() == "\(baseName.lowercased()).zip" {
                    foundParts[1] = file
                    totalSize += (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                } else if name.lowercased().hasPrefix(baseName.lowercased() + ".z") {
                    let ext = file.pathExtension.lowercased()
                    if let num = Int(ext.dropFirst()) {
                        foundParts[num + 1] = file
                        totalSize += (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                    }
                }
            }
        }

        let sortedIndices = foundParts.keys.sorted()
        let maxIndex = sortedIndices.last ?? currentIndex
        var missingIndices: [Int] = []

        for expected in 1...max(maxIndex, 1) {
            if foundParts[expected] == nil {
                missingIndices.append(expected)
            }
        }

        let orderedURLs = sortedIndices.compactMap { foundParts[$0] }

        return MultiPartVolumeInfo(
            isMultiPart: true,
            baseName: baseName,
            currentPartIndex: currentIndex,
            allPartURLs: orderedURLs,
            missingPartIndices: missingIndices,
            totalDetectedParts: foundParts.count,
            totalByteSize: totalSize
        )
    }
}
