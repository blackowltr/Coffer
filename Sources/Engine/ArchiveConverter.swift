import Foundation

/// Arşivi doğrudan farklı bir formata dönüştüren motor (ör. .rar -> .7z veya .zip -> .tar.gz)
public final class ArchiveConverter: Sendable {
    public static let shared = ArchiveConverter()

    private init() {}

    public func convert(
        sourceURL: URL,
        targetFormat: ArchiveFormat,
        targetLevel: CompressionLevel,
        targetURL: URL,
        password: String? = nil
    ) -> AsyncThrowingStream<ArchiveProgress, Error> {
        return AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Coffer_Convert")
                    .appendingPathComponent(UUID().uuidString)

                do {
                    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                    // 1. Aşama: Kaynak Arşivi Geçici Dizine Çıkar (%0 - %50)
                    let extractStream = await ArchiveManager.shared.extract(
                        archiveURL: sourceURL,
                        destinationURL: tempDir,
                        password: password
                    )

                    for try await extractProg in extractStream {
                        if Task.isCancelled {
                            try? FileManager.default.removeItem(at: tempDir)
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        continuation.yield(
                            ArchiveProgress(
                                fractionCompleted: extractProg.fractionCompleted * 0.5,
                                currentFilename: "Çözülüyor: \(extractProg.currentFilename)",
                                processedBytes: extractProg.processedBytes,
                                totalBytes: extractProg.totalBytes * 2,
                                speedBytesPerSecond: extractProg.speedBytesPerSecond
                            )
                        )
                    }

                    // 2. Aşama: Hedef Formatla Yeni Arşiv Oluştur (%50 - %100)
                    let compressStream = await ArchiveManager.shared.compress(
                        sourceURLs: [tempDir],
                        destinationURL: targetURL,
                        format: targetFormat,
                        level: targetLevel,
                        password: password,
                        stripMacJunk: true
                    )

                    for try await compProg in compressStream {
                        if Task.isCancelled {
                            try? FileManager.default.removeItem(at: tempDir)
                            try? FileManager.default.removeItem(at: targetURL)
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        continuation.yield(
                            ArchiveProgress(
                                fractionCompleted: 0.5 + (compProg.fractionCompleted * 0.5),
                                currentFilename: "Paketleniyor: \(targetURL.lastPathComponent)",
                                processedBytes: compProg.processedBytes,
                                totalBytes: compProg.totalBytes,
                                speedBytesPerSecond: compProg.speedBytesPerSecond
                            )
                        )
                    }

                    // Temizlik
                    try? FileManager.default.removeItem(at: tempDir)

                    continuation.yield(
                        ArchiveProgress(
                            fractionCompleted: 1.0,
                            currentFilename: "Dönüştürme Tamamlandı",
                            processedBytes: 100,
                            totalBytes: 100
                        )
                    )
                    continuation.finish()
                } catch {
                    try? FileManager.default.removeItem(at: tempDir)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
