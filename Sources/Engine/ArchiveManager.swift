import Foundation

private final class SessionPasswordStore: @unchecked Sendable {
    private let lock = NSLock()
    private var passwords: [URL: String] = [:]

    func get(_ url: URL) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return passwords[url]
    }

    func set(_ pass: String, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        passwords[url] = pass
    }

    func remove(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        passwords.removeValue(forKey: url)
    }
}

/// Tüm arşivleme, çıkarma, onarım ve analiz işlemlerini koordine eden merkezi Swift Actor
public actor ArchiveManager {
    public static let shared = ArchiveManager()

    private let sevenZipEngine = SevenZipEngine()
    private let tarEngine = TarZipEngine()
    private let unrarEngine = UnrarEngine()

    private var currentTask: Task<Void, Error>?

    /// Bu oturum süresince parola korumalı arşivler için hatırlanan parolalar (Session Passwords)
    private let sessionPasswordStore = SessionPasswordStore()

    public init() {}

    public func cancelCurrentOperation() {
        currentTask?.cancel()
        currentTask = nil
    }

    nonisolated public func getSessionPassword(for url: URL) -> String? {
        sessionPasswordStore.get(url)
    }

    nonisolated public func setSessionPassword(_ pass: String, for url: URL) {
        sessionPasswordStore.set(pass, for: url)
    }

    nonisolated public func clearSessionPassword(for url: URL) {
        sessionPasswordStore.remove(for: url)
    }

    // MARK: - Arşiv Açma & İçerik Listeleme

    public func openArchive(at url: URL, password: String? = nil) async throws -> (items: [ArchiveItem], metadata: ArchiveMetadata) {
        let effectivePassword = password ?? sessionPasswordStore.get(url)

        if SevenZipEngine.available7zPath != nil {
            do {
                let result = try await sevenZipEngine.listArchive(at: url, password: effectivePassword)
                if let pass = effectivePassword {
                    sessionPasswordStore.set(pass, for: url)
                }
                return result
            } catch let err as SevenZipError {
                if case .encryptedArchivePasswordRequired = err {
                    throw err
                }
                if case .wrongPassword = err {
                    sessionPasswordStore.remove(for: url)
                    throw err
                }
            } catch {
                // Diğer durumlarda alternatif motorlara geç
            }
        }

        let format = ArchiveFormat.detect(from: url) ?? .zip
        let archiveFileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        switch format {
        case .rar:
            return try unrarEngine.listArchive(at: url)

        case .zip, .sevenZip, .tar, .tarGz, .tarBz2, .tarXz, .zstd, .iso, .dmg, .cab:
            let items = try await tarEngine.listArchive(at: url)
            let dirCount = items.filter { $0.isDirectory }.count
            let fileCount = items.count - dirCount
            let totalUncompressed = items.reduce(0) { $0 + $1.uncompressedSize }

            let metadata = ArchiveMetadata(
                format: format,
                archiveURL: url,
                totalFileCount: fileCount,
                totalDirectoryCount: dirCount,
                totalUncompressedSize: totalUncompressed,
                archiveFileSize: archiveFileSize,
                isEncrypted: false,
                isMultiVolume: false,
                hasRecoveryRecord: false
            )

            return (items, metadata)
        }
    }

    // MARK: - Çıkarma İşlemi (Extraction)

    public func extract(
        archiveURL: URL,
        destinationURL: URL,
        selectedItems: [ArchiveItem]? = nil,
        password: String? = nil
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        let effectivePassword = password ?? sessionPasswordStore.get(archiveURL)

        if SevenZipEngine.available7zPath != nil {
            return sevenZipEngine.extract(
                archiveURL: archiveURL,
                destinationURL: destinationURL,
                selectedItems: selectedItems,
                password: effectivePassword
            )
        }

        let format = ArchiveFormat.detect(from: archiveURL) ?? .zip
        if format == .rar {
            return unrarEngine.extract(
                archiveURL: archiveURL,
                destinationURL: destinationURL,
                selectedItems: selectedItems,
                password: effectivePassword
            )
        } else {
            return tarEngine.extract(
                archiveURL: archiveURL,
                destinationURL: destinationURL,
                selectedItems: selectedItems,
                password: effectivePassword
            )
        }
    }

    // MARK: - Sıkıştırma İşlemi (Compression)

    public func compress(
        sourceURLs: [URL],
        destinationURL: URL,
        format: ArchiveFormat,
        level: CompressionLevel = .normal,
        password: String? = nil,
        encryptHeaders: Bool = false,
        isSolid: Bool = true,
        splitVolumeSizeMB: Int? = nil,
        recoveryRecordPercentage: Int? = 3,
        isSFX: Bool = false,
        deleteSources: Bool = false,
        stripMacJunk: Bool = true
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        if format == .rar {
            return unrarEngine.compress(
                sourceURLs: sourceURLs,
                destinationURL: destinationURL,
                level: level,
                password: password,
                encryptHeaders: encryptHeaders,
                isSolid: isSolid,
                splitVolumeSizeMB: splitVolumeSizeMB,
                recoveryRecordPercentage: recoveryRecordPercentage,
                isSFX: isSFX,
                deleteSources: deleteSources,
                stripMacJunk: stripMacJunk
            )
        }

        if format == .sevenZip || format == .zip || format == .tar {
            if SevenZipEngine.available7zPath != nil {
                return sevenZipEngine.compress(
                    sourceURLs: sourceURLs,
                    destinationURL: destinationURL,
                    format: format,
                    level: level,
                    password: password,
                    encryptHeaders: encryptHeaders,
                    isSolid: isSolid,
                    splitVolumeSizeMB: splitVolumeSizeMB,
                    isSFX: isSFX,
                    deleteSources: deleteSources,
                    stripMacJunk: stripMacJunk
                )
            }
        }

        return tarEngine.compress(
            sourceURLs: sourceURLs,
            destinationURL: destinationURL,
            format: format,
            level: level,
            password: password,
            stripMacJunk: stripMacJunk
        )
    }

    // MARK: - Arşive Dosya Ekleme (Add Files)

    public func addFiles(to archiveURL: URL, files: [URL]) async throws {
        let ext = archiveURL.pathExtension.lowercased()
        if ext == "rar" {
            try await unrarEngine.addFilesToArchive(archiveURL: archiveURL, files: files)
        } else if SevenZipEngine.available7zPath != nil {
            try await sevenZipEngine.addFilesToArchive(archiveURL: archiveURL, files: files)
        } else {
            try await tarEngine.addFilesToArchive(archiveURL: archiveURL, files: files)
        }
    }

    // MARK: - Arşivden Dosya Silme (Delete Items)

    public func deleteItems(from archiveURL: URL, items: [ArchiveItem]) async throws {
        let ext = archiveURL.pathExtension.lowercased()
        let paths = items.map { $0.path }
        if ext == "rar" {
            try await unrarEngine.deleteItemsFromArchive(archiveURL: archiveURL, itemPaths: paths)
        } else if SevenZipEngine.available7zPath != nil {
            try await sevenZipEngine.deleteItemsFromArchive(archiveURL: archiveURL, itemPaths: paths)
        } else {
            try await tarEngine.deleteItemsFromArchive(archiveURL: archiveURL, itemPaths: paths)
        }
    }

    // MARK: - Arşiv Onarma (Repair Archive)

    public func repairArchive(url: URL) async throws -> URL {
        return try await tarEngine.repairArchive(url: url)
    }

    // MARK: - Arşivi Parola ile Yeniden Kilitleme

    public func lockArchiveWithPassword(archiveURL: URL, password: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnPack_Lock")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let stream = extract(archiveURL: archiveURL, destinationURL: tempDir)
        for try await _ in stream {}

        let targetLockedURL = archiveURL.deletingPathExtension()
            .appendingPathExtension("kilitli.zip")

        let compressStream = compress(
            sourceURLs: [tempDir],
            destinationURL: targetLockedURL,
            format: .zip,
            level: .good,
            password: password,
            stripMacJunk: true
        )
        for try await _ in compressStream {}

        try? FileManager.default.removeItem(at: tempDir)
        return targetLockedURL
    }

    // MARK: - Bütünlük Testi (Integrity Test)

    public func testIntegrity(of url: URL, password: String? = nil) async throws -> ArchiveTestResult {
        let effectivePassword = password ?? sessionPasswordStore.get(url)
        if SevenZipEngine.available7zPath != nil {
            return try await sevenZipEngine.testArchive(at: url, password: effectivePassword)
        }
        return try await tarEngine.testArchive(at: url, password: effectivePassword)
    }

    // MARK: - Quick Look İçin Tekil Dosya Ayıklama (Önizleme)

    public func extractItemForPreview(archiveURL: URL, item: ArchiveItem, password: String? = nil) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnPack_Preview")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let effectivePassword = password ?? sessionPasswordStore.get(archiveURL)

        let stream = extract(
            archiveURL: archiveURL,
            destinationURL: tempDir,
            selectedItems: [item],
            password: effectivePassword
        )

        for try await _ in stream {}

        let extractedFileURL = tempDir.appendingPathComponent(item.path)
        if FileManager.default.fileExists(atPath: extractedFileURL.path) {
            return extractedFileURL
        }

        if let subpaths = try? FileManager.default.subpathsOfDirectory(atPath: tempDir.path) {
            for subpath in subpaths {
                let candidateURL = tempDir.appendingPathComponent(subpath)
                if candidateURL.lastPathComponent == item.name {
                    return candidateURL
                }
            }
        }

        return extractedFileURL
    }

    // MARK: - Drag Out (Masaüstüne ve Diğer Uygulamalara Sürükle-Bırak)

    nonisolated public func extractItemSynchronouslyForDrag(archiveURL: URL, item: ArchiveItem) -> URL? {
        let dragDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnPack_DragOut")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dragDir, withIntermediateDirectories: true)

        let targetFileURL = dragDir.appendingPathComponent(item.name)

        if let sevenZip = SevenZipEngine.available7zPath {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sevenZip)
            var args = ["e", "-y", archiveURL.path, "-o\(dragDir.path)", item.path]
            if let pass = getSessionPassword(for: archiveURL) {
                args.append("-p\(pass)")
            } else {
                args.append("-p-")
            }
            process.arguments = args
            try? process.run()
            process.waitUntilExit()
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xf", archiveURL.path, "-C", dragDir.path, item.path]
            try? process.run()
            process.waitUntilExit()
        }

        if FileManager.default.fileExists(atPath: targetFileURL.path) {
            return targetFileURL
        }

        if let subpaths = try? FileManager.default.subpathsOfDirectory(atPath: dragDir.path) {
            for sub in subpaths {
                let candidate = dragDir.appendingPathComponent(sub)
                if candidate.lastPathComponent == item.name {
                    return candidate
                }
            }
        }

        return nil
    }
}
