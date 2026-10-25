import Foundation

/// RAR formatı için özel çıkarma, sıkıştırma ve test motoru
public final class UnrarEngine: Sendable {
    public static let shared = UnrarEngine()
    private let rarParser = NativeRARParser()

    public init() {}

    /// Sistemde veya UnPack içinde mevcut bir unrar ikilisini bulur (statik önbelleklenir)
    private static let _cachedUnrarPath: String? = {
        var candidates: [String] = []
        if let res = Bundle.main.resourcePath {
            candidates.append("\(res)/bin/unrar")
            candidates.append("\(res)/unrar")
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/unrar").path)
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin/unrar").path)
        candidates.append("/opt/homebrew/bin/unrar")
        candidates.append("/usr/local/bin/unrar")
        candidates.append("/opt/homebrew/bin/unar")
        candidates.append("/usr/local/bin/unar")
        candidates.append("Resources/bin/unrar")

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }()

    public static var availableUnrarPath: String? {
        _cachedUnrarPath
    }

    /// Sistemde veya UnPack içinde mevcut bir rar ikilisini bulur (statik önbelleklenir)
    private static let _cachedRarPath: String? = {
        var candidates: [String] = []
        if let res = Bundle.main.resourcePath {
            candidates.append("\(res)/bin/rar")
            candidates.append("\(res)/rar")
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/rar").path)
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin/rar").path)
        candidates.append("/opt/homebrew/bin/rar")
        candidates.append("/usr/local/bin/rar")
        candidates.append("Resources/bin/rar")

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }()

    public static var availableRarPath: String? {
        _cachedRarPath
    }

    /// RAR arşivini Swift Native Parser ile doğrudan okur (sıfır harici bağımlılık)
    public func listArchive(at url: URL) throws -> (items: [ArchiveItem], metadata: ArchiveMetadata) {
        return try rarParser.parseArchive(at: url)
    }

    /// RAR arşivini hedef dizine çıkartır
    public func extract(
        archiveURL: URL,
        destinationURL: URL,
        selectedItems: [ArchiveItem]? = nil,
        password: String? = nil
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

                    let startTime = Date()
                    let totalSize = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64) ?? 1024

                    if let unrarBin = UnrarEngine.availableUnrarPath {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: unrarBin)

                        var args: [String] = []
                        if unrarBin.hasSuffix("unar") {
                            args = ["-o", destinationURL.path, archiveURL.path]
                            if let pass = password, !pass.isEmpty {
                                args.append(contentsOf: ["-p", pass])
                            }
                        } else {
                            args = ["x", "-y", "-o+"]
                            if let pass = password, !pass.isEmpty {
                                args.append("-p\(pass)")
                            } else {
                                args.append("-p-")
                            }
                            args.append(archiveURL.path)
                            args.append(destinationURL.path + "/")
                        }

                        process.arguments = args
                        let pipe = Pipe()
                        process.standardOutput = pipe
                        process.standardError = Pipe()

                        try process.run()
                        process.waitUntilExit()

                        if process.terminationStatus != 0 {
                            throw RARParserError.corruptedArchive("Çıkarma işlemi unrar motoru ile tamamlanamadı.")
                        }
                    } else {
                        let tarEngine = TarZipEngine()
                        for try await prog in tarEngine.extract(archiveURL: archiveURL, destinationURL: destinationURL, selectedItems: selectedItems, password: password) {
                            continuation.yield(prog)
                        }
                        continuation.finish()
                        return
                    }

                    continuation.yield(
                        ArchiveProgress(
                            fractionCompleted: 1.0,
                            currentFilename: "Tamamlandı",
                            processedBytes: totalSize,
                            totalBytes: totalSize,
                            speedBytesPerSecond: Double(totalSize) / max(Date().timeIntervalSince(startTime), 0.001)
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// RAR formatında yeni arşiv oluşturur (RARLAB Resmi macOS Motoru)
    public func compress(
        sourceURLs: [URL],
        destinationURL: URL,
        level: CompressionLevel,
        password: String? = nil,
        encryptHeaders: Bool = false,
        isSolid: Bool = true,
        splitVolumeSizeMB: Int? = nil,
        recoveryRecordPercentage: Int? = 3,
        isSFX: Bool = false,
        deleteSources: Bool = false,
        stripMacJunk: Bool = true
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    guard let rarBin = UnrarEngine.availableRarPath else {
                        throw RARParserError.corruptedArchive("RAR sıkıştırma motoru (rar) bulunamadı. Lütfen Ayarlar -> RAR Aracını Yükle seçeneğini kullanın.")
                    }

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: rarBin)

                    let mLevel: String
                    switch level {
                    case .store: mLevel = "-m0"
                    case .fastest: mLevel = "-m1"
                    case .fast: mLevel = "-m2"
                    case .normal: mLevel = "-m3"
                    case .good: mLevel = "-m4"
                    case .best: mLevel = "-m5"
                    }

                    var args: [String] = ["a", "-y", mLevel, "-ep1"]

                    if isSolid {
                        args.append("-s")
                    }

                    if isSFX {
                        args.append("-sfx")
                    }

                    if deleteSources {
                        args.append("-df")
                    }

                    if let rr = recoveryRecordPercentage, rr > 0 {
                        args.append("-rr\(rr)p")
                    }

                    if let splitMB = splitVolumeSizeMB, splitMB > 0 {
                        args.append("-v\(splitMB)m")
                    }

                    if stripMacJunk {
                        args.append(contentsOf: [
                            "-x*.DS_Store",
                            "-x*__MACOSX*",
                            "-x*._*",
                            "-x*.Spotlight-V100*",
                            "-x*.Trashes*",
                            "-x*Thumbs.db",
                            "-x*desktop.ini"
                        ])
                    }

                    if let pass = password, !pass.isEmpty {
                        if encryptHeaders {
                            args.append("-hp\(pass)")
                        } else {
                            args.append("-p\(pass)")
                        }
                    } else {
                        args.append("-p-")
                    }

                    let commonParent = sourceURLs.first?.deletingLastPathComponent().path ?? FileManager.default.currentDirectoryPath
                    let allInSameParent = sourceURLs.allSatisfy { $0.deletingLastPathComponent().path == commonParent }

                    args.append(destinationURL.path)

                    if allInSameParent {
                        process.currentDirectoryURL = URL(fileURLWithPath: commonParent)
                        for src in sourceURLs {
                            args.append(src.lastPathComponent)
                        }
                    } else {
                        for src in sourceURLs {
                            args.append(src.path)
                        }
                    }

                    process.arguments = args
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    let errPipe = Pipe()
                    process.standardError = errPipe

                    let startTime = Date()
                    let sourceStats = CompressionSimulator.shared.analyzeSources(urls: sourceURLs)
                    let totalSourceSize = max(Int64(1024), sourceStats.totalSize)
                    let totalFilesCount = max(1, sourceStats.fileCount)

                    var processedLogs: [String] = []
                    var currentFraction: Double = 0.05
                    var lastYieldTime: TimeInterval = 0

                    try process.run()

                    let outHandle = pipe.fileHandleForReading

                    while process.isRunning {
                        if Task.isCancelled {
                            process.terminate()
                            try? FileManager.default.removeItem(at: destinationURL)
                            continuation.finish(throwing: CancellationError())
                            return
                        }

                        let data = outHandle.availableData
                        if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                            for line in text.components(separatedBy: .newlines) {
                                let trimmed = line.trimmingCharacters(in: .whitespaces)
                                if trimmed.hasPrefix("Adding ") {
                                    let fn = String(trimmed.dropFirst(7)).components(separatedBy: " ").first ?? trimmed
                                    if !processedLogs.contains(fn) {
                                        processedLogs.append(fn)
                                    }
                                }
                            }
                        }

                        let now = Date().timeIntervalSinceReferenceDate
                        if now - lastYieldTime >= 0.033 {
                            lastYieldTime = now
                            let elapsed = max(Date().timeIntervalSince(startTime), 0.001)

                            // 1. Eklenen dosya sayısına göre oran:
                            let fileRatio = Double(processedLogs.count) / Double(totalFilesCount)

                            // 2. Diske yazılan dosya boyutuna göre oran:
                            let writtenBytes = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
                            let estimatedCompressedTotal = max(Int64(1024), Int64(Double(totalSourceSize) * 0.55))
                            let byteRatio = Double(writtenBytes) / Double(estimatedCompressedTotal)

                            // 3. Geçen süreye göre adaptif akış:
                            let expectedDuration = max(2.0, Double(totalSourceSize) / 20_000_000.0)
                            let timeRatio = 1.0 - exp(-elapsed / expectedDuration * 1.2)

                            // İlerlemeyi akıcı ve monoton artan şekilde harmanla (Asla aniden %95'e zıplamaz):
                            let targetFraction = min(0.985, max(fileRatio * 0.92, max(byteRatio * 0.90, timeRatio * 0.88)))
                            currentFraction = max(currentFraction, targetFraction)

                            let processed = Int64(Double(totalSourceSize) * currentFraction)
                            let speed = Double(processed) / elapsed
                            let estRemaining = currentFraction > 0.03 ? max(0.5, (elapsed / currentFraction) * (1.0 - currentFraction)) : nil

                            continuation.yield(
                                ArchiveProgress(
                                    fractionCompleted: currentFraction,
                                    currentFilename: processedLogs.last ?? (sourceURLs.first?.lastPathComponent ?? "RAR arşivi oluşturuluyor..."),
                                    processedBytes: processed,
                                    totalBytes: totalSourceSize,
                                    speedBytesPerSecond: speed,
                                    estimatedRemainingTime: estRemaining,
                                    elapsedTime: elapsed,
                                    processedLog: processedLogs
                                )
                            )
                        }

                        try? await Task.sleep(nanoseconds: 25_000_000)
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 && process.terminationStatus != 1 {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? "RAR oluşturma hatası (\(process.terminationStatus))."
                        throw RARParserError.corruptedArchive("RAR arşivi oluşturulamadı: \(errMsg)")
                    }

                    let totalElapsed = max(Date().timeIntervalSince(startTime), 0.001)
                    continuation.yield(
                        ArchiveProgress(
                            fractionCompleted: 1.0,
                            currentFilename: "Tamamlandı",
                            processedBytes: totalSourceSize,
                            totalBytes: totalSourceSize,
                            speedBytesPerSecond: Double(totalSourceSize) / totalElapsed,
                            estimatedRemainingTime: 0,
                            elapsedTime: totalElapsed,
                            processedLog: processedLogs
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - RAR Arşive Dosya Ekleme (rar a)

    public func addFilesToArchive(archiveURL: URL, files: [URL]) async throws {
        return try await Task.detached(priority: .userInitiated) {
            guard let rarBin = UnrarEngine.availableRarPath else {
                throw RARParserError.corruptedArchive("RAR aracı bulunamadı.")
            }

            let cleanFiles = files.filter { !AppleJunkSanitizer.shared.isJunk(path: $0.path) }
            guard !cleanFiles.isEmpty else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: rarBin)
            var args = ["a", "-y", "-ep1", archiveURL.path]
            for f in cleanFiles {
                args.append(f.path)
            }
            process.arguments = args
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 && process.terminationStatus != 1 {
                throw RARParserError.corruptedArchive("Dosyalar RAR arşivine eklenemedi.")
            }
        }.value
    }

    // MARK: - RAR Arşivden Dosya Silme (rar d)

    public func deleteItemsFromArchive(archiveURL: URL, itemPaths: [String]) async throws {
        return try await Task.detached(priority: .userInitiated) {
            guard let rarBin = UnrarEngine.availableRarPath else {
                throw RARParserError.corruptedArchive("RAR aracı bulunamadı.")
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: rarBin)
            var args = ["d", "-y", archiveURL.path]
            args.append(contentsOf: itemPaths)
            process.arguments = args
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 && process.terminationStatus != 1 {
                throw RARParserError.corruptedArchive("Dosyalar RAR arşivinden silinemedi.")
            }
        }.value
    }
}
