import Foundation

/// 7-Zip (7zz) universal ikilisi üzerinden tüm arşiv formatlarını açan, listeleyen,
/// çıkartan, test eden ve sıkıştıran yüksek performanslı motor.
public final class SevenZipEngine: Sendable {
    public static let shared = SevenZipEngine()

    public init() {}

    /// Sistemde veya uygulama paketinde 7zz ikilisini bulur
    public static var available7zPath: String? {
        var candidates: [String] = []

        if let res = Bundle.main.resourcePath {
            candidates.append("\(res)/bin/7zz")
            candidates.append("\(res)/7zz")
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/7zz").path)
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin/7zz").path)
        candidates.append("/opt/homebrew/bin/7zz")
        candidates.append("/usr/local/bin/7zz")
        candidates.append("Resources/bin/7zz")

        let currentDir = FileManager.default.currentDirectoryPath
        candidates.append("\(currentDir)/Resources/bin/7zz")

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Arşiv Listeleme (7zz l -slt)

    public func listArchive(at url: URL, password: String? = nil) async throws -> (items: [ArchiveItem], metadata: ArchiveMetadata) {
        return try await Task.detached(priority: .userInitiated) {
            guard let binary = Self.available7zPath else {
                throw SevenZipError.binaryNotFound
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            var env = ProcessInfo.processInfo.environment
            env["LC_ALL"] = "C"
            process.environment = env

            var args = ["l", "-slt"]
            if let pass = password, !pass.isEmpty {
                args.append("-p\(pass)")
            } else {
                args.append("-p-")
            }
            args.append(url.path)
            process.arguments = args

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()
            let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: outData, encoding: .utf8) ?? ""
            let errOutput = String(data: errData, encoding: .utf8) ?? ""

            // Parola koruması tespiti
            if output.contains("Cannot open encrypted archive") ||
                errOutput.contains("Cannot open encrypted archive") ||
                output.contains("Wrong password") ||
                errOutput.contains("Wrong password") {
                throw SevenZipError.encryptedArchivePasswordRequired
            }

            guard process.terminationStatus == 0 else {
                throw SevenZipError.executionFailed(errOutput.isEmpty ? "Arşiv okunamadı (Kod: \(process.terminationStatus))" : errOutput)
            }

            return self.parseTechnicalListing(output: output, archiveURL: url)
        }.value
    }

    // Paylaşımlı Statik Tarih Formatlayıcı (Tek defa oluşturulur)
    private static let staticDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private func parseTechnicalListing(output: String, archiveURL: URL) -> (items: [ArchiveItem], metadata: ArchiveMetadata) {
        let separator = "----------"
        var headerSection = output
        var recordsSection = ""

        if let range = output.range(of: separator) {
            headerSection = String(output[..<range.lowerBound])
            recordsSection = String(output[range.upperBound...])
        }

        // Header Parsing
        var archiveType = ArchiveFormat.detect(from: archiveURL) ?? .zip
        var isSolid = false
        var isMultiVolume = false
        var volumeCount = 1
        var hasEncryptedHeaders = false
        var physicalSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64) ?? 0

        headerSection.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Type = ") {
                let val = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces).lowercased()
                if val.contains("rar") { archiveType = .rar }
                else if val == "7z" { archiveType = .sevenZip }
                else if val == "zip" { archiveType = .zip }
                else if val == "tar" { archiveType = .tar }
            } else if trimmed.hasPrefix("Solid = ") {
                isSolid = trimmed.contains("+")
            } else if trimmed.hasPrefix("Multivolume = ") {
                isMultiVolume = trimmed.contains("+")
            } else if trimmed.hasPrefix("Volumes = ") {
                if let v = Int(trimmed.dropFirst(10).trimmingCharacters(in: .whitespaces)) {
                    volumeCount = v
                    if v > 1 { isMultiVolume = true }
                }
            } else if trimmed.hasPrefix("Encrypted = ") {
                hasEncryptedHeaders = trimmed.contains("+")
            } else if trimmed.hasPrefix("Physical Size = ") {
                if let s = Int64(trimmed.dropFirst(16).trimmingCharacters(in: .whitespaces)) {
                    physicalSize = s
                }
            }
        }

        // Items Parsing (Sıfır Dizi Bölme / Streaming Line-by-Line)
        var items: [ArchiveItem] = []
        var anyItemEncrypted = hasEncryptedHeaders

        var currentPath: String?
        var isFolder = false
        var size: Int64 = 0
        var packedSize: Int64 = 0
        var modDate: Date?
        var isEncrypted = false
        var crc: String?

        func commitCurrentRecord() {
            guard let path = currentPath, !path.isEmpty else { return }
            items.append(
                ArchiveItem(
                    path: path,
                    uncompressedSize: size,
                    compressedSize: packedSize > 0 ? packedSize : size,
                    modificationDate: modDate,
                    isDirectory: isFolder,
                    isEncrypted: isEncrypted,
                    crc32: crc
                )
            )
            currentPath = nil
            isFolder = false
            size = 0
            packedSize = 0
            modDate = nil
            isEncrypted = false
            crc = nil
        }

        recordsSection.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                commitCurrentRecord()
                return
            }

            guard let eqIdx = trimmed.firstIndex(of: "=") else { return }
            let key = trimmed[..<eqIdx].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: eqIdx)...].trimmingCharacters(in: .whitespaces)

            switch key {
            case "Path":
                // Eğer önceki kayıt henüz tamamlanmadan yeni bir Path geldiyse kaydet
                if currentPath != nil {
                    commitCurrentRecord()
                }
                currentPath = value
            case "Folder":
                isFolder = (value == "+")
            case "Size":
                size = Int64(value) ?? 0
            case "Packed Size":
                packedSize = Int64(value) ?? 0
            case "Modified":
                let cleanDateStr = String(value.prefix(19))
                modDate = Self.staticDateFormatter.date(from: cleanDateStr)
            case "Encrypted":
                isEncrypted = (value == "+")
                if isEncrypted { anyItemEncrypted = true }
            case "CRC":
                crc = value.isEmpty ? nil : value.uppercased()
            default:
                break
            }
        }

        // Son kalan kaydı ekle
        commitCurrentRecord()

        let dirCount = items.filter { $0.isDirectory }.count
        let fileCount = items.count - dirCount
        let totalUncompressed = items.reduce(0) { $0 + $1.uncompressedSize }

        let metadata = ArchiveMetadata(
            format: archiveType,
            archiveURL: archiveURL,
            totalFileCount: fileCount,
            totalDirectoryCount: dirCount,
            totalUncompressedSize: totalUncompressed,
            archiveFileSize: physicalSize,
            isEncrypted: anyItemEncrypted,
            hasEncryptedHeaders: hasEncryptedHeaders,
            isSolid: isSolid,
            isMultiVolume: isMultiVolume,
            volumeCount: volumeCount,
            hasRecoveryRecord: false
        )

        return (items, metadata)
    }

    // MARK: - Arşiv Çıkarma (Extraction with 7zz)

    public func extract(
        archiveURL: URL,
        destinationURL: URL,
        selectedItems: [ArchiveItem]? = nil,
        password: String? = nil
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    guard let binary = Self.available7zPath else {
                        throw SevenZipError.binaryNotFound
                    }

                    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: binary)
                    var env = ProcessInfo.processInfo.environment
                    env["LC_ALL"] = "C"
                    process.environment = env

                    var args = ["x", "-y", "-bsp1", "-o\(destinationURL.path)"]

                    if let pass = password, !pass.isEmpty {
                        args.append("-p\(pass)")
                    } else {
                        args.append("-p-")
                    }

                    args.append(archiveURL.path)

                    if let selected = selectedItems, !selected.isEmpty {
                        for item in selected {
                            args.append(item.path)
                        }
                    }

                    process.arguments = args

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    let startTime = Date()
                    let totalArchiveSize = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64) ?? 1024
                    var processedLogs: [String] = []
                    var seenLogs = Set<String>()
                    var lastYieldTime: Double = 0

                    try process.run()

                    let outHandle = stdoutPipe.fileHandleForReading
                    var currentFraction: Double = 0.0
                    var currentFilename: String = "Ayıklanıyor..."

                    while process.isRunning {
                        if Task.isCancelled {
                            process.terminate()
                            continuation.finish(throwing: CancellationError())
                            return
                        }

                        let data = outHandle.availableData
                        if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                            let lines = text.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
                            for line in lines {
                                let trimmed = line.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { continue }

                                // 7zz progress format: " 35% 12 - filename.ext" or "Extracting archive: ..."
                                if let percentIdx = trimmed.firstIndex(of: "%") {
                                    let percentStr = trimmed[..<percentIdx].trimmingCharacters(in: .whitespaces)
                                    if let pct = Double(percentStr) {
                                        currentFraction = max(currentFraction, pct / 100.0)
                                    }
                                    let remainder = trimmed[trimmed.index(after: percentIdx)...].trimmingCharacters(in: .whitespaces)
                                    if !remainder.isEmpty {
                                        currentFilename = remainder
                                        if !seenLogs.contains(remainder) {
                                            seenLogs.insert(remainder)
                                            processedLogs.append(remainder)
                                            if processedLogs.count > 80 {
                                                processedLogs.removeFirst(15)
                                            }
                                        }
                                    }
                                } else if trimmed.hasPrefix("Extracting ") {
                                    let fn = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
                                    currentFilename = fn
                                    if !seenLogs.contains(fn) {
                                        seenLogs.insert(fn)
                                        processedLogs.append(fn)
                                        if processedLogs.count > 80 {
                                            processedLogs.removeFirst(15)
                                        }
                                    }
                                }
                            }

                            // Arayüzü 30 FPS (~33ms) ile sınırla (SwiftUI akıcılığını korur)
                            let now = Date().timeIntervalSinceReferenceDate
                            if now - lastYieldTime >= 0.033 {
                                lastYieldTime = now
                                let elapsed = max(Date().timeIntervalSince(startTime), 0.001)
                                let processedBytes = Int64(Double(totalArchiveSize) * currentFraction)
                                let speed = Double(processedBytes) / elapsed
                                let estRemaining = currentFraction > 0.02 ? (elapsed / currentFraction) * (1.0 - currentFraction) : nil

                                continuation.yield(
                                    ArchiveProgress(
                                        fractionCompleted: currentFraction,
                                        currentFilename: currentFilename,
                                        processedBytes: processedBytes,
                                        totalBytes: totalArchiveSize,
                                        speedBytesPerSecond: speed,
                                        estimatedRemainingTime: estRemaining,
                                        elapsedTime: elapsed,
                                        processedLog: processedLogs
                                    )
                                )
                            }
                        }
                        try? await Task.sleep(nanoseconds: 20_000_000)
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errText = String(data: errData, encoding: .utf8) ?? ""
                        if errText.contains("Wrong password") || errText.contains("Cannot open encrypted archive") {
                            throw SevenZipError.wrongPassword
                        }
                        throw SevenZipError.executionFailed(errText.isEmpty ? "Çıkarma işlemi tamamlanamadı (\(process.terminationStatus))" : errText)
                    }

                    let totalElapsed = max(Date().timeIntervalSince(startTime), 0.001)
                    continuation.yield(
                        ArchiveProgress(
                            fractionCompleted: 1.0,
                            currentFilename: "Tamamlandı",
                            processedBytes: totalArchiveSize,
                            totalBytes: totalArchiveSize,
                            speedBytesPerSecond: Double(totalArchiveSize) / totalElapsed,
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

    // MARK: - Arşiv Testi (7zz t)

    public func testArchive(at url: URL, password: String? = nil) async throws -> ArchiveTestResult {
        return try await Task.detached(priority: .userInitiated) {
            guard let binary = Self.available7zPath else {
                throw SevenZipError.binaryNotFound
            }

            let start = Date()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            var env = ProcessInfo.processInfo.environment
            env["LC_ALL"] = "C"
            process.environment = env

            var args = ["t"]
            if let pass = password, !pass.isEmpty {
                args.append("-p\(pass)")
            } else {
                args.append("-p-")
            }
            args.append(url.path)
            process.arguments = args

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let duration = Date().timeIntervalSince(start)
            let outStr = String(data: stdoutData, encoding: .utf8) ?? ""
            let errStr = String(data: stderrData, encoding: .utf8) ?? ""

            var count = 0
            for line in outStr.components(separatedBy: .newlines) {
                if line.contains("Testing archive:") || line.contains("Everything is Ok") { continue }
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                count += 1
            }

            if process.terminationStatus == 0 {
                return ArchiveTestResult(isSuccess: true, totalItemsChecked: max(1, count), errors: [], duration: duration)
            } else {
                let errs = errStr.components(separatedBy: .newlines).filter { !$0.isEmpty }
                return ArchiveTestResult(isSuccess: false, totalItemsChecked: count, errors: errs.isEmpty ? [outStr] : errs, duration: duration)
            }
        }.value
    }

    // MARK: - Arşiv Sıkıştırma / Oluşturma (7zz a)

    public func compress(
        sourceURLs: [URL],
        destinationURL: URL,
        format: ArchiveFormat,
        level: CompressionLevel,
        password: String? = nil,
        encryptHeaders: Bool = false,
        isSolid: Bool = true,
        splitVolumeSizeMB: Int? = nil,
        isSFX: Bool = false,
        deleteSources: Bool = false,
        stripMacJunk: Bool = true
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    guard let binary = Self.available7zPath else {
                        throw SevenZipError.binaryNotFound
                    }
                    guard !sourceURLs.isEmpty else {
                        throw SevenZipError.executionFailed("Sıkıştırılacak dosya seçilmedi.")
                    }

                    var totalSourceSize: Int64 = 0
                    for src in sourceURLs {
                        let attrs = try? FileManager.default.attributesOfItem(atPath: src.path)
                        totalSourceSize += (attrs?[.size] as? Int64) ?? 1024
                    }

                    let startTime = Date()
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: binary)
                    var env = ProcessInfo.processInfo.environment
                    env["LC_ALL"] = "C"
                    process.environment = env

                    var args = ["a", "-y", "-bsp1"]

                    // Format parametresi
                    switch format {
                    case .sevenZip:
                        args.append("-t7z")
                    case .zip:
                        args.append("-tzip")
                        // ZIP AES-256 şifreleme
                        if password != nil {
                            args.append("-mem=AES256")
                        }
                    case .tar:
                        args.append("-ttar")
                    default:
                        args.append("-t7z")
                    }

                    // Sıkıştırma seviyesi (-mx0 ... -mx9)
                    args.append("-mx\(level.rawValue)")

                    // Katı Arşiv (Solid)
                    if format == .sevenZip {
                        args.append(isSolid ? "-ms=on" : "-ms=off")
                    }

                    // Parola ve Başlık Şifreleme (-p / -mhe)
                    if let pass = password, !pass.isEmpty {
                        args.append("-p\(pass)")
                        if encryptHeaders && format == .sevenZip {
                            args.append("-mhe=on")
                        }
                    }

                    // Çok Parçalı Arşiv (-v)
                    if let splitMB = splitVolumeSizeMB, splitMB > 0 {
                        args.append("-v\(splitMB)m")
                    }

                    // Kaynakları sil (-sdel)
                    if deleteSources {
                        args.append("-sdel")
                    }

                    // SFX (Kendinden açılan arşiv)
                    if isSFX && format == .sevenZip {
                        args.append("-sfx")
                    }

                    // macOS gereksiz dosyalarını hariç tut
                    if stripMacJunk {
                        args.append(contentsOf: [
                            "-xr!.DS_Store",
                            "-xr!__MACOSX",
                            "-xr!._*",
                            "-xr!Thumbs.db",
                            "-xr!desktop.ini"
                        ])
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

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    var processedLogs: [String] = []
                    var seenLogs = Set<String>()
                    var lastYieldTime: Double = 0

                    try process.run()

                    let outHandle = stdoutPipe.fileHandleForReading
                    var currentFraction: Double = 0.0
                    var currentFilename: String = sourceURLs.first?.lastPathComponent ?? "Sıkıştırılıyor..."

                    while process.isRunning {
                        if Task.isCancelled {
                            process.terminate()
                            try? FileManager.default.removeItem(at: destinationURL)
                            continuation.finish(throwing: CancellationError())
                            return
                        }

                        let data = outHandle.availableData
                        if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                            let lines = text.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
                            for line in lines {
                                let trimmed = line.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { continue }

                                if let percentIdx = trimmed.firstIndex(of: "%") {
                                    let percentStr = trimmed[..<percentIdx].trimmingCharacters(in: .whitespaces)
                                    if let pct = Double(percentStr) {
                                        currentFraction = max(currentFraction, pct / 100.0)
                                    }
                                    let remainder = trimmed[trimmed.index(after: percentIdx)...].trimmingCharacters(in: .whitespaces)
                                    if !remainder.isEmpty {
                                        currentFilename = remainder
                                        if !seenLogs.contains(remainder) {
                                            seenLogs.insert(remainder)
                                            processedLogs.append(remainder)
                                            if processedLogs.count > 80 {
                                                processedLogs.removeFirst(15)
                                            }
                                        }
                                    }
                                }
                            }

                            // Arayüzü 30 FPS (~33ms) ile sınırla (SwiftUI akıcılığını korur)
                            let now = Date().timeIntervalSinceReferenceDate
                            if now - lastYieldTime >= 0.033 {
                                lastYieldTime = now
                                let elapsed = max(Date().timeIntervalSince(startTime), 0.001)
                                let processedBytes = Int64(Double(totalSourceSize) * currentFraction)
                                let speed = Double(processedBytes) / elapsed
                                let estRemaining = currentFraction > 0.02 ? (elapsed / currentFraction) * (1.0 - currentFraction) : nil

                                continuation.yield(
                                    ArchiveProgress(
                                        fractionCompleted: currentFraction,
                                        currentFilename: currentFilename,
                                        processedBytes: processedBytes,
                                        totalBytes: max(1, totalSourceSize),
                                        speedBytesPerSecond: speed,
                                        estimatedRemainingTime: estRemaining,
                                        elapsedTime: elapsed,
                                        processedLog: processedLogs
                                    )
                                )
                            }
                        }
                        try? await Task.sleep(nanoseconds: 25_000_000)
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errText = String(data: errData, encoding: .utf8) ?? ""
                        throw SevenZipError.executionFailed(errText.isEmpty ? "Arşivleme başarısız (\(process.terminationStatus))" : errText)
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

    // MARK: - Arşive Dosya Ekleme (7zz a)

    public func addFilesToArchive(archiveURL: URL, files: [URL]) async throws {
        return try await Task.detached(priority: .userInitiated) {
            guard let binary = Self.available7zPath else {
                throw SevenZipError.binaryNotFound
            }

            let cleanFiles = files.filter { !AppleJunkSanitizer.shared.isJunk(path: $0.path) }
            guard !cleanFiles.isEmpty else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            var args = ["a", "-y", archiveURL.path]
            for file in cleanFiles {
                args.append(file.path)
            }

            process.arguments = args
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw SevenZipError.executionFailed("Dosyalar arşive eklenemedi (\(process.terminationStatus))")
            }
        }.value
    }

    // MARK: - Arşivden Dosya Silme (7zz d)

    public func deleteItemsFromArchive(archiveURL: URL, itemPaths: [String]) async throws {
        return try await Task.detached(priority: .userInitiated) {
            guard let binary = Self.available7zPath else {
                throw SevenZipError.binaryNotFound
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            var args = ["d", "-y", archiveURL.path]
            args.append(contentsOf: itemPaths)

            process.arguments = args
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw SevenZipError.executionFailed("Dosyalar arşivden silinemedi (\(process.terminationStatus))")
            }
        }.value
    }
}

public enum SevenZipError: LocalizedError {
    case binaryNotFound
    case encryptedArchivePasswordRequired
    case wrongPassword
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "7-Zip motoru (7zz) bulunamadı."
        case .encryptedArchivePasswordRequired:
            return "Bu arşiv şifrelidir. Lütfen parolanızı girin."
        case .wrongPassword:
            return "Hatalı parola! Lütfen tekrar deneyin."
        case .executionFailed(let msg):
            return "İşlem başarısız: \(msg)"
        }
    }
}
