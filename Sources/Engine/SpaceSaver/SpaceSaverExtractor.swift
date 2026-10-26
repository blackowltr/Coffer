import Foundation

/// Düşük Disk Alanı Modu (Space-Saving In-Place Extraction)
/// Büyük arşivleri, çıkarılan dosyaların kapladığı disk bloklarını adım adım
/// serbest bırakarak (APFS Punch Hole / Reverse Truncation) minimum boş alanda çıkartır.
public final class SpaceSaverExtractor: Sendable {
    public static let shared = SpaceSaverExtractor()

    private init() {}

    public enum SpaceSaverError: LocalizedError {
        case insufficientSpace(available: String, required: String)
        case binaryNotFound
        case extractionFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .insufficientSpace(let available, let required):
                return "Diskte alan açarak çıkarma için dahi yeterli boş alan bulunmuyor (Mevcut: \(available), En Az Gereken: \(required))."
            case .binaryNotFound:
                return "Arşiv çıkarma motoru (7zz) bulunamadı."
            case .extractionFailed(let msg):
                return "Alan açarak çıkarma sırasında hata oluştu: \(msg)"
            case .cancelled:
                return "Çıkarma işlemi kullanıcı tarafından iptal edildi."
            }
        }
    }

    /// Alan açarak çıkarma akışını başlatır
    public func extract(
        archiveURL: URL,
        destinationURL: URL,
        items: [ArchiveItem],
        selectedItems: [ArchiveItem]? = nil,
        password: String? = nil,
        isResume: Bool = false
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    guard let binary = SevenZipEngine.available7zPath else {
                        throw SpaceSaverError.binaryNotFound
                    }

                    // 1. Önceden Alan Analizi (Pre-flight Check)
                    let itemsToExtract = selectedItems ?? items
                    let preflight = SpaceRequirementEstimator.shared.evaluate(
                        archiveURL: archiveURL,
                        destinationURL: destinationURL,
                        items: itemsToExtract
                    )

                    if !preflight.canExtractSpaceSaver && !isResume {
                        throw SpaceSaverError.insufficientSpace(
                            available: preflight.availableDiskFormatted,
                            required: preflight.spaceSaverRequiredFormatted
                        )
                    }

                    // Hedef klasörü hazırla
                    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

                    // 2. Günlük Kaydı (Journal) Yönetimi - Crash Resilience
                    let journalManager = SpaceSaverJournal.shared
                    var record: SpaceSaverJournal.Record

                    if isResume, let existing = journalManager.readJournal(for: archiveURL) {
                        record = existing
                        record.status = .inProgress
                        record.updatedAt = Date()
                    } else {
                        let originalSize = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64) ?? 0
                        record = SpaceSaverJournal.Record(
                            archivePath: archiveURL.path,
                            destinationPath: destinationURL.path,
                            originalArchiveSize: originalSize,
                            currentArchiveSize: originalSize,
                            status: .inProgress
                        )
                    }
                    journalManager.writeJournal(record: record, for: archiveURL)

                    // Tamamlanmış olanları filtrele (Resume desteği)
                    let completedSet = Set(record.completedItems)
                    let remainingItems = itemsToExtract.filter { !completedSet.contains($0.path) }

                    let totalBytes = itemsToExtract.reduce(0) { $0 + $1.uncompressedSize }
                    var processedBytes: Int64 = itemsToExtract.filter { completedSet.contains($0.path) }.reduce(0) { $0 + $1.uncompressedSize }
                    var freedBytes: Int64 = record.freedBytes

                    let startTime = Date()
                    var processedLogs: [String] = []
                    if !completedSet.isEmpty {
                        processedLogs.append("⚡ [Devam Edildi] Önceden çıkarılan \(completedSet.count) dosya atlandı.")
                    }

                    let isAPFS = APFSPunchHole.isAPFS(at: archiveURL)
                    let archiveFd = open(archiveURL.path, O_RDWR)
                    defer {
                        if archiveFd >= 0 {
                            close(archiveFd)
                        }
                    }

                    // 3. Dosyaları Ofset Sırasına Göre Düzenle (Ters ofset veya sıralı blok)
                    // Ofseti bilinenleri sondan başa doğru (reverse order) sıralamak ftruncate için idealdir
                    let sortedItems = remainingItems.sorted { a, b in
                        (a.headerOffset ?? 0) > (b.headerOffset ?? 0)
                    }

                    // 4. Dinamik Gruplama (Batching)
                    // Boş alana sığacak şekilde maksimum 256 dosya veya 300 MB gruplar halinde işlenir
                    var batches: [[ArchiveItem]] = []
                    var currentBatch: [ArchiveItem] = []
                    var currentBatchSize: Int64 = 0

                    for item in sortedItems {
                        if item.isDirectory {
                            currentBatch.append(item)
                            continue
                        }

                        if currentBatchSize + item.uncompressedSize > 300 * 1024 * 1024 || currentBatch.count >= 256 {
                            if !currentBatch.isEmpty {
                                batches.append(currentBatch)
                                currentBatch = []
                                currentBatchSize = 0
                            }
                        }

                        currentBatch.append(item)
                        currentBatchSize += item.uncompressedSize
                    }
                    if !currentBatch.isEmpty {
                        batches.append(currentBatch)
                    }

                    // 5. Adım Adım Çıkarma ve Blok Serbest Bırakma Döngüsü
                    for batch in batches {
                        if Task.isCancelled {
                            journalManager.markInterrupted(for: archiveURL)
                            throw SpaceSaverError.cancelled
                        }

                        // Sadece dosya olanları argüman olarak ver
                        let filePaths = batch.filter { !$0.isDirectory }.map(\.path)
                        if !filePaths.isEmpty {
                            try await Self.extractBatch(
                                binary: binary,
                                archiveURL: archiveURL,
                                destinationURL: destinationURL,
                                filePaths: filePaths,
                                password: password
                            )
                        }

                        // Batch içindeki her bir dosyayı doğrula, fiziksel diske yaz ve arşivden alan aç
                        for item in batch {
                            let itemURL = destinationURL.appendingPathComponent(item.path)

                            // Fiziksel diske commit et (Full Fsync)
                            if !item.isDirectory && FileManager.default.fileExists(atPath: itemURL.path) {
                                APFSPunchHole.fullSync(at: itemURL)
                            }

                            // Alan Açma (APFS Sparse Hole Punching & Truncation)
                            if !item.isDirectory {
                                let packed = item.compressedSize > 0 ? item.compressedSize : item.uncompressedSize

                                if isAPFS && archiveFd >= 0, let offset = item.headerOffset, offset >= 0 {
                                    // APFS üzerinde delik aç (Punch hole)
                                    if APFSPunchHole.punchHole(fileDescriptor: archiveFd, offset: offset, length: packed) {
                                        freedBytes += packed
                                    }
                                } else if archiveFd >= 0, let offset = item.headerOffset, offset > 0 {
                                    // APFS dışındaki sistemlerde ters kısaltma (Reverse ftruncate)
                                    if APFSPunchHole.truncate(fileDescriptor: archiveFd, newLength: offset) {
                                        freedBytes += packed
                                    }
                                }

                                record.completedItems.append(item.path)
                                record.freedBytes = freedBytes
                                processedBytes += item.uncompressedSize

                                let freedFormatted = ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
                                let logMsg = "⚡ [Alan Açıldı] \(item.name) (Toplam +\(freedFormatted) serbest)"
                                processedLogs.append(logMsg)
                                if processedLogs.count > 100 {
                                    processedLogs.removeFirst()
                                }

                                let fraction = min(1.0, Double(processedBytes) / Double(max(1, totalBytes)))
                                let elapsed = Date().timeIntervalSince(startTime)
                                let speed = elapsed > 0 ? Double(processedBytes) / elapsed : 0
                                let remaining = speed > 0 ? Double(max(0, totalBytes - processedBytes)) / speed : nil

                                continuation.yield(
                                    ArchiveProgress(
                                        fractionCompleted: fraction,
                                        currentFilename: item.name,
                                        processedBytes: processedBytes,
                                        totalBytes: totalBytes,
                                        speedBytesPerSecond: speed,
                                        estimatedRemainingTime: remaining,
                                        elapsedTime: elapsed,
                                        processedLog: processedLogs,
                                        freedBytes: freedBytes
                                    )
                                )
                            }
                        }

                        // Her batch sonrasında günlüğü diske atomik yaz
                        record.updatedAt = Date()
                        journalManager.writeJournal(record: record, for: archiveURL)
                    }

                    // 6. Çok Parçalı Arşiv (Multi-part) Tamamlanan Ciltleri Temizleme
                    let multiPartInfo = MultiPartVolumeManager.shared.analyzeArchive(at: archiveURL)
                    if multiPartInfo.isMultiPart {
                        for partURL in multiPartInfo.allPartURLs {
                            _ = try? FileManager.default.removeItem(at: partURL)
                        }
                    } else {
                        // Tek parça arşiv bittiğinde kalan arşivi temizle
                        _ = try? FileManager.default.removeItem(at: archiveURL)
                    }

                    // 7. Günlük ve Kuyruk Dosyalarını Başarıyla Temizle
                    record.status = .completed
                    journalManager.deleteJournalAndTail(for: archiveURL)

                    // Tamamlanma bildirimini ilet
                    continuation.yield(
                        ArchiveProgress(
                            fractionCompleted: 1.0,
                            currentFilename: "Alan açılarak çıkarma başarıyla tamamlandı!",
                            processedBytes: totalBytes,
                            totalBytes: totalBytes,
                            speedBytesPerSecond: 0,
                            estimatedRemainingTime: 0,
                            elapsedTime: Date().timeIntervalSince(startTime),
                            processedLog: processedLogs + ["✓ Çıkarma tamamlandı. Arşiv alanı sisteme geri kazandırıldı."],
                            freedBytes: freedBytes
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 7zz ile bir grup dosyayı hedef dizine ayıklar
    private static func extractBatch(
        binary: String,
        archiveURL: URL,
        destinationURL: URL,
        filePaths: [String],
        password: String?
    ) async throws {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            var env = ProcessInfo.processInfo.environment
            env["LC_ALL"] = "C"
            process.environment = env

            var args = ["x", "-y", "-bsp0", "-o\(destinationURL.path)"]
            if let pass = password, !pass.isEmpty {
                args.append("-p\(pass)")
            } else {
                args.append("-p-")
            }
            args.append(archiveURL.path)

            for path in filePaths {
                args.append(path)
            }
            process.arguments = args

            let errPipe = Pipe()
            process.standardError = errPipe
            process.standardOutput = Pipe()

            try process.run()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errStr = String(data: errData, encoding: .utf8) ?? "Bilinmeyen hata"
                throw SpaceSaverError.extractionFailed(errStr)
            }
        }.value
    }
}
