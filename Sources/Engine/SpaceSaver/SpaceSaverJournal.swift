import Foundation

/// Çökme ve kesinti dayanıklılığı sağlayan alan açarak çıkarma günlüğü (Journaling)
/// İşlem yarıda kesilirse veriyi kaybetmeden kaldığı yerden devam ettirir.
public final class SpaceSaverJournal: Sendable {
    public static let shared = SpaceSaverJournal()

    private init() {}

    public enum Status: String, Codable, Sendable {
        case inProgress = "in_progress"
        case interrupted = "interrupted"
        case completed = "completed"
    }

    public struct Record: Codable, Sendable {
        public let archivePath: String
        public let destinationPath: String
        public let originalArchiveSize: Int64
        public var currentArchiveSize: Int64
        public var freedBytes: Int64
        public var completedItems: [String]
        public var tailSaved: Bool
        public var tailOffset: Int64?
        public var tailLength: Int64?
        public var status: Status
        public var updatedAt: Date

        public init(
            archivePath: String,
            destinationPath: String,
            originalArchiveSize: Int64,
            currentArchiveSize: Int64,
            freedBytes: Int64 = 0,
            completedItems: [String] = [],
            tailSaved: Bool = false,
            tailOffset: Int64? = nil,
            tailLength: Int64? = nil,
            status: Status = .inProgress,
            updatedAt: Date = Date()
        ) {
            self.archivePath = archivePath
            self.destinationPath = destinationPath
            self.originalArchiveSize = originalArchiveSize
            self.currentArchiveSize = currentArchiveSize
            self.freedBytes = freedBytes
            self.completedItems = completedItems
            self.tailSaved = tailSaved
            self.tailOffset = tailOffset
            self.tailLength = tailLength
            self.status = status
            self.updatedAt = updatedAt
        }
    }

    /// Verilen arşiv için günlük dosyası URL'sini döner
    public func journalURL(for archiveURL: URL) -> URL {
        let basePath = archiveURL.deletingPathExtension().path
        return URL(fileURLWithPath: basePath + ".unpack-journal.json")
    }

    /// Arşivin saklanan kuyruk (Central Directory) dosya URL'sini döner
    public func tailURL(for archiveURL: URL) -> URL {
        let basePath = archiveURL.deletingPathExtension().path
        return URL(fileURLWithPath: basePath + ".unpack-tail")
    }

    /// Arşiv için aktif veya yarıda kalmış bir günlük var mı kontrol eder
    public func hasActiveJournal(for archiveURL: URL) -> Bool {
        guard let record = readJournal(for: archiveURL) else { return false }
        return record.status != .completed
    }

    /// Günlük dosyasını okur
    public func readJournal(for archiveURL: URL) -> Record? {
        let fileURL = journalURL(for: archiveURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Record.self, from: data)
        } catch {
            return nil
        }
    }

    /// Günlük dosyasını atomik olarak kaydeder (Crash Resilience)
    public func writeJournal(record: Record, for archiveURL: URL) {
        let fileURL = journalURL(for: archiveURL)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(record)

            let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent(".\(fileURL.lastPathComponent).tmp")
            try data.write(to: tempURL, options: .atomic)
            _ = try? FileManager.default.removeItem(at: fileURL)
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        } catch {
            // Hata sessizce loglanabilir
        }
    }

    /// Durumu kesintiye uğradı olarak işaretler
    public func markInterrupted(for archiveURL: URL) {
        if var record = readJournal(for: archiveURL) {
            record.status = .interrupted
            record.updatedAt = Date()
            writeJournal(record: record, for: archiveURL)
        }
    }

    /// Çıkarma başarıyla tamamlandığında günlük ve kuyruk dosyalarını temizler
    public func deleteJournalAndTail(for archiveURL: URL) {
        let jURL = journalURL(for: archiveURL)
        let tURL = tailURL(for: archiveURL)
        _ = try? FileManager.default.removeItem(at: jURL)
        _ = try? FileManager.default.removeItem(at: tURL)
    }
}
