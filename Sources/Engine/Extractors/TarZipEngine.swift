import Foundation

/// macOS Dahili bsdtar (libarchive) ve zip araçlarını kullanan yüksek performanslı motor
public final class TarZipEngine: Sendable {

    public init() {}

    // MARK: - Arşiv İçeriğini Listeleme (Listing)

    private static let monthAbbreviations: Set<String> = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    public func listArchive(at url: URL) async throws -> [ArchiveItem] {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            var env = ProcessInfo.processInfo.environment
            env["LC_ALL"] = "C"
            env["COPYFILE_DISABLE"] = "1"
            process.environment = env
            process.arguments = ["-tvf", url.path]

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            try process.run()

            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }

            return self.parseTarOutput(output)
        }.value
    }

    private func parseTarOutput(_ output: String) -> [ArchiveItem] {
        var items: [ArchiveItem] = []

        output.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }

            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 6 else { return }

            let permissions = parts[0]
            let isDirByPerm = permissions.hasPrefix("d")

            // POSIX/bsdtar formatı:
            // <mode> <links> <owner> <group> <size> <Month> <Day> <Time/Year> <filepath...>
            var monthIdx = -1
            for (idx, part) in parts.enumerated() {
                if idx >= 3 && idx < parts.count - 3 && Self.monthAbbreviations.contains(part) {
                    monthIdx = idx
                    break
                }
            }

            var size: Int64 = 0
            var rawFilePath = ""

            if monthIdx != -1 && monthIdx + 3 < parts.count {
                let sizeStr = parts[monthIdx - 1]
                size = Int64(sizeStr) ?? 0
                rawFilePath = parts[(monthIdx + 3)...].joined(separator: " ")
            } else {
                var foundSizeIdx = -1
                for idx in stride(from: min(parts.count - 3, 5), through: 3, by: -1) {
                    if let parsedSize = Int64(parts[idx]) {
                        size = parsedSize
                        foundSizeIdx = idx
                        break
                    }
                }
                if foundSizeIdx != -1 && foundSizeIdx + 3 < parts.count {
                    rawFilePath = parts[(foundSizeIdx + 3)...].joined(separator: " ")
                } else {
                    rawFilePath = parts.suffix(from: max(0, parts.count - 1)).joined(separator: " ")
                }
            }

            // Sembolik bağlar (symlink -> target) varsa sadece asıl dosya yolunu al
            if let linkArrowRange = rawFilePath.range(of: " -> ") {
                rawFilePath = String(rawFilePath[..<linkArrowRange.lowerBound])
            }

            let cleanPath = rawFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanPath.isEmpty, !cleanPath.contains("..") else { return }

            let isDir = isDirByPerm || cleanPath.hasSuffix("/")

            items.append(
                ArchiveItem(
                    path: cleanPath,
                    uncompressedSize: size,
                    compressedSize: size > 0 ? Int64(Double(size) * 0.72) : 0,
                    modificationDate: nil,
                    isDirectory: isDir,
                    isEncrypted: false,
                    crc32: nil
                )
            )
        }

        return items
    }

    // MARK: - Arşiv Çıkarma (Extraction)

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

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")

                    var env = ProcessInfo.processInfo.environment
                    env["COPYFILE_DISABLE"] = "1"
                    env["COPY_EXTENDED_ATTRIBUTES_DISABLE"] = "1"
                    process.environment = env

                    var args = ["-xvf", archiveURL.path, "-C", destinationURL.path]

                    if AppSettings.shared.stripMacJunkFiles {
                        args.append(contentsOf: [
                            "--exclude", ".DS_Store",
                            "--exclude", "*/.DS_Store",
                            "--exclude", "._*",
                            "--exclude", "*/._*",
                            "--exclude", "__MACOSX",
                            "--exclude", "*__MACOSX*",
                            "--exclude", "*/__MACOSX/*",
                            "--exclude", "Thumbs.db",
                            "--exclude", "desktop.ini"
                        ])
                    }

                    if let pass = password, !pass.isEmpty {
                        args.append(contentsOf: ["--passphrase", pass])
                    }

                    if let selected = selectedItems, !selected.isEmpty {
                        for item in selected {
                            let targetFile = destinationURL.appendingPathComponent(item.path).standardizedFileURL
                            guard targetFile.path.hasPrefix(destinationURL.standardizedFileURL.path) else {
                                throw TarEngineError.securityViolation("Zararlı yol aşımı (Path traversal) engellendi: \(item.path)")
                            }
                            args.append(item.path)
                        }
                    }

                    process.arguments = args

                    let stdoutPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    let stderrPipe = Pipe()
                    process.standardError = stderrPipe

                    let startTime = Date()
                    let totalArchiveSize = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64) ?? 1024

                    try process.run()

                    let outHandle = stdoutPipe.fileHandleForReading
                    var buffer = Data()
                    var extractedCount = 0

                    while process.isRunning {
                        if Task.isCancelled {
                            process.terminate()
                            continuation.finish(throwing: CancellationError())
                            return
                        }

                        let chunk = outHandle.availableData
                        if !chunk.isEmpty {
                            buffer.append(chunk)
                            if let text = String(data: buffer, encoding: .utf8) {
                                let lines = text.components(separatedBy: .newlines)
                                for line in lines.dropLast() {
                                    let filename = line.trimmingCharacters(in: .whitespaces)
                                    guard !filename.isEmpty else { continue }
                                    extractedCount += 1

                                    let elapsed = max(Date().timeIntervalSince(startTime), 0.001)
                                    let simulatedProcessed = min(totalArchiveSize, Int64(Double(totalArchiveSize) * min(Double(extractedCount) / 100.0, 0.95)))
                                    let speed = Double(simulatedProcessed) / elapsed

                                    continuation.yield(
                                        ArchiveProgress(
                                            fractionCompleted: min(Double(extractedCount) / 100.0, 0.95),
                                            currentFilename: filename,
                                            processedBytes: simulatedProcessed,
                                            totalBytes: totalArchiveSize,
                                            speedBytesPerSecond: speed
                                        )
                                    )
                                }
                                if let last = lines.last {
                                    buffer = last.data(using: .utf8) ?? Data()
                                }
                            }
                        }
                        try? await Task.sleep(nanoseconds: 10_000_000)
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Ayıklama işlemi başarısız oldu."
                        throw TarEngineError.executionFailed(errMsg)
                    }

                    continuation.yield(
                        ArchiveProgress(
                            fractionCompleted: 1.0,
                            currentFilename: "Tamamlandı",
                            processedBytes: totalArchiveSize,
                            totalBytes: totalArchiveSize,
                            speedBytesPerSecond: 0,
                            estimatedRemainingTime: 0
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Arşiv Oluşturma / Sıkıştırma (Compression)

    public func compress(
        sourceURLs: [URL],
        destinationURL: URL,
        format: ArchiveFormat,
        level: CompressionLevel,
        password: String? = nil,
        stripMacJunk: Bool = true
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    guard !sourceURLs.isEmpty else {
                        throw TarEngineError.executionFailed("Sıkıştırılacak dosya seçilmedi.")
                    }

                    let startTime = Date()
                    let sourceStats = CompressionSimulator.shared.analyzeSources(urls: sourceURLs)
                    let totalSourceSize = max(Int64(1024), sourceStats.totalSize)

                    let process = Process()
                    var env = ProcessInfo.processInfo.environment
                    env["COPYFILE_DISABLE"] = "1"
                    process.environment = env

                    if format == .zip {
                        // ZIP formatı: /usr/bin/zip ile doğrudan sıkıştırma
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                        var args = ["-r", "-q"]

                        // Sıkıştırma seviyesi (-0 to -9)
                        let zipLevel: String
                        switch level {
                        case .store: zipLevel = "-0"
                        case .fastest: zipLevel = "-1"
                        case .fast: zipLevel = "-3"
                        case .normal: zipLevel = "-6"
                        case .good: zipLevel = "-8"
                        case .best: zipLevel = "-9"
                        }
                        args.append(zipLevel)

                        if let pass = password, !pass.isEmpty {
                            args.append(contentsOf: ["-P", pass])
                        }

                        args.append(destinationURL.path)

                        // Ortak üst dizin varsa oradan çalıştır, böylece tam yol kirliliği oluşmaz
                        let commonParent = sourceURLs.first?.deletingLastPathComponent().path ?? FileManager.default.currentDirectoryPath
                        let allInSameParent = sourceURLs.allSatisfy { $0.deletingLastPathComponent().path == commonParent }

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

                        if stripMacJunk {
                            args.append(contentsOf: [
                                "-x", "*.DS_Store",
                                "-x", "*__MACOSX*",
                                "-x", "*._*",
                                "-x", "*Thumbs.db",
                                "-x", "*desktop.ini"
                            ])
                        }

                        process.arguments = args
                    } else {
                        // TAR / TAR.GZ / TAR.BZ2 / TAR.XZ formatları: /usr/bin/tar
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                        var args: [String] = []

                        switch format {
                        case .tarGz: args.append("-czf")
                        case .tarBz2: args.append("-cjf")
                        case .tarXz: args.append("-cJf")
                        default: args.append("-cf")
                        }

                        args.append(destinationURL.path)

                        if stripMacJunk {
                            args.append(contentsOf: [
                                "--exclude", ".DS_Store",
                                "--exclude", "._*",
                                "--exclude", "__MACOSX",
                                "--exclude", "Thumbs.db",
                                "--exclude", "desktop.ini"
                            ])
                        }

                        for src in sourceURLs {
                            let parent = src.deletingLastPathComponent().path
                            let name = src.lastPathComponent
                            args.append("-C")
                            args.append(parent)
                            args.append(name)
                        }

                        process.arguments = args
                    }

                    let stdoutPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    let stderrPipe = Pipe()
                    process.standardError = stderrPipe

                    try process.run()

                    var currentFraction: Double = 0.05
                    var lastYieldTime: TimeInterval = 0

                    while process.isRunning {
                        if Task.isCancelled {
                            process.terminate()
                            try? FileManager.default.removeItem(at: destinationURL)
                            continuation.finish(throwing: CancellationError())
                            return
                        }

                        let now = Date().timeIntervalSinceReferenceDate
                        if now - lastYieldTime >= 0.033 {
                            lastYieldTime = now
                            let elapsed = max(Date().timeIntervalSince(startTime), 0.001)

                            // Yazılan dosya boyutu ve zamana göre dengeli, akıcı oran:
                            let writtenBytes = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
                            let estimatedCompressedTotal = max(Int64(2048), Int64(Double(totalSourceSize) * 0.55))
                            let rawRatio = min(Double(writtenBytes) / Double(estimatedCompressedTotal), 0.98)

                            let expectedDuration = max(2.5, Double(totalSourceSize) / 20_000_000.0)
                            let timeRatio = min(0.96, elapsed / expectedDuration)

                            // Gerçek yazılan veriyi önceliklendir, takılmayı önleyen doğrusal yumuşatma uygula
                            let targetFraction = min(0.98, max(rawRatio * 0.95, timeRatio * 0.85))
                            currentFraction = max(currentFraction, targetFraction)

                            let processed = Int64(Double(totalSourceSize) * currentFraction)
                            let speed = Double(processed) / elapsed
                            let estRemaining = currentFraction > 0.03 ? max(0.5, (elapsed / currentFraction) * (1.0 - currentFraction)) : nil

                            continuation.yield(
                                ArchiveProgress(
                                    fractionCompleted: currentFraction,
                                    currentFilename: sourceURLs.first?.lastPathComponent ?? "Arşiv sıkıştırılıyor...",
                                    processedBytes: processed,
                                    totalBytes: totalSourceSize,
                                    speedBytesPerSecond: speed,
                                    estimatedRemainingTime: estRemaining,
                                    elapsedTime: elapsed
                                )
                            )
                        }

                        try? await Task.sleep(nanoseconds: 25_000_000)
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Arşiv oluşturma tamamlanamadı (\(process.terminationStatus))."
                        throw TarEngineError.executionFailed(errMsg)
                    }

                    continuation.yield(
                        ArchiveProgress(
                            fractionCompleted: 1.0,
                            currentFilename: "Tamamlandı",
                            processedBytes: totalSourceSize,
                            totalBytes: totalSourceSize,
                            speedBytesPerSecond: Double(totalSourceSize) / max(Date().timeIntervalSince(startTime), 0.001),
                            estimatedRemainingTime: 0
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Arşive Dosya Ekleme (Add to Archive)

    public func addFilesToArchive(archiveURL: URL, files: [URL]) async throws {
        return try await Task.detached(priority: .userInitiated) {
            let ext = archiveURL.pathExtension.lowercased()
            let cleanFiles = files.filter { !AppleJunkSanitizer.shared.isJunk(path: $0.path) }
            guard !cleanFiles.isEmpty else { return }

            if ext == "zip" {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                var env = ProcessInfo.processInfo.environment
                env["COPYFILE_DISABLE"] = "1"
                env["COPY_EXTENDED_ATTRIBUTES_DISABLE"] = "1"
                process.environment = env

                var args = ["-u", "-r", archiveURL.path]
                for file in cleanFiles {
                    args.append(file.path)
                }
                args.append(contentsOf: [
                    "-x", "*.DS_Store*", "*__MACOSX*", "*._*", "*Thumbs.db*", "*desktop.ini*"
                ])
                process.arguments = args
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 && process.terminationStatus != 12 {
                    throw TarEngineError.executionFailed("Dosyalar ZIP arşivine eklenemedi.")
                }
            } else {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                var env = ProcessInfo.processInfo.environment
                env["COPYFILE_DISABLE"] = "1"
                env["COPY_EXTENDED_ATTRIBUTES_DISABLE"] = "1"
                process.environment = env

                var args = [
                    "-rf", archiveURL.path,
                    "--no-xattrs", "--no-mac-metadata",
                    "--exclude", ".DS_Store", "--exclude", "*/.DS_Store",
                    "--exclude", "._*", "--exclude", "*/._*",
                    "--exclude", "__MACOSX", "--exclude", "*__MACOSX*"
                ]
                for file in cleanFiles {
                    let parent = file.deletingLastPathComponent().path
                    let name = file.lastPathComponent
                    args.append("-C")
                    args.append(parent)
                    args.append(name)
                }
                process.arguments = args
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    throw TarEngineError.executionFailed("Dosyalar arşive eklenemedi.")
                }
            }
        }.value
    }

    // MARK: - Arşivden Dosya Silme (Delete from Archive)

    public func deleteItemsFromArchive(archiveURL: URL, itemPaths: [String]) async throws {
        return try await Task.detached(priority: .userInitiated) {
            let ext = archiveURL.pathExtension.lowercased()

            if ext == "zip" {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                var args = ["-d", archiveURL.path]
                args.append(contentsOf: itemPaths)
                process.arguments = args

                try process.run()
                process.waitUntilExit()
                // Durum 0 (başarılı) veya 12 (ZE_NONE - eşleşen dosya kalmadı/silindi) kabul edilir
                if process.terminationStatus != 0 && process.terminationStatus != 12 {
                    throw TarEngineError.executionFailed("Seçilen dosyalar arşivden silinemedi.")
                }
            } else {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("UnPack_Rebuild")
                    .appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let extractProcess = Process()
                extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                extractProcess.arguments = ["-xf", archiveURL.path, "-C", tempDir.path]
                try extractProcess.run()
                extractProcess.waitUntilExit()

                for path in itemPaths {
                    let target = tempDir.appendingPathComponent(path)
                    try? FileManager.default.removeItem(at: target)
                }

                let format = ArchiveFormat.detect(from: archiveURL) ?? .tarGz
                let tempArchive = tempDir.appendingPathComponent("repacked." + format.primaryExtension)

                let repackProcess = Process()
                repackProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                var env = ProcessInfo.processInfo.environment
                env["COPYFILE_DISABLE"] = "1"
                repackProcess.environment = env

                var args: [String] = []
                switch format {
                case .tarGz: args = ["-czf", tempArchive.path, "-C", tempDir.path, "."]
                case .tarBz2: args = ["-cjf", tempArchive.path, "-C", tempDir.path, "."]
                case .tarXz: args = ["-cJf", tempArchive.path, "-C", tempDir.path, "."]
                default: args = ["-cf", tempArchive.path, "-C", tempDir.path, "."]
                }
                repackProcess.arguments = args
                try repackProcess.run()
                repackProcess.waitUntilExit()

                _ = try? FileManager.default.removeItem(at: archiveURL)
                try FileManager.default.moveItem(at: tempArchive, to: archiveURL)
                try? FileManager.default.removeItem(at: tempDir)
            }
        }.value
    }

    // MARK: - Arşiv Onarma (Repair Archive)

    public func repairArchive(url: URL) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let ext = url.pathExtension.lowercased()
            let repairedURL = url.deletingPathExtension()
                .appendingPathExtension("onarildi.\(ext)")

            if ext == "zip" {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.arguments = ["-FF", url.path, "--out", repairedURL.path]

                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: repairedURL.path) {
                    return repairedURL
                }
            }

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("UnPack_Repair")
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let extractProcess = Process()
            extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            extractProcess.arguments = ["-xkf", url.path, "-C", tempDir.path]
            try? extractProcess.run()
            extractProcess.waitUntilExit()

            let repackProcess = Process()
            repackProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            repackProcess.arguments = ["-a", "-cf", repairedURL.path, "-C", tempDir.path, "."]
            try repackProcess.run()
            repackProcess.waitUntilExit()

            try? FileManager.default.removeItem(at: tempDir)
            return repairedURL
        }.value
    }

    // MARK: - Bütünlük Denetimi (Test Integrity)

    public func testArchive(at url: URL, password: String? = nil) async throws -> ArchiveTestResult {
        return try await Task.detached(priority: .userInitiated) {
            let start = Date()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")

            var args = ["-tf", url.path]
            if let pass = password, !pass.isEmpty {
                args.append(contentsOf: ["--passphrase", pass])
            }
            process.arguments = args

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            let stderrPipe = Pipe()
            process.standardError = stderrPipe

            try process.run()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let duration = Date().timeIntervalSince(start)
            let outStr = String(data: stdoutData, encoding: .utf8) ?? ""
            let errStr = String(data: stderrData, encoding: .utf8) ?? ""

            let count = outStr.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

            if process.terminationStatus == 0 {
                return ArchiveTestResult(isSuccess: true, totalItemsChecked: count, errors: [], duration: duration)
            } else {
                let errs = errStr.components(separatedBy: .newlines).filter { !$0.isEmpty }
                return ArchiveTestResult(isSuccess: false, totalItemsChecked: count, errors: errs, duration: duration)
            }
        }.value
    }
}

public enum TarEngineError: LocalizedError {
    case executionFailed(String)
    case securityViolation(String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "İşlem başarısız oldu: \(msg)"
        case .securityViolation(let msg): return "Güvenlik Engeli: \(msg)"
        }
    }
}
