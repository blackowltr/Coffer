import Foundation

/// İki arşiv arasındaki farkları (Diff) hesaplayan analiz motoru
public final class ArchiveDiffEngine: Sendable {
    public static let shared = ArchiveDiffEngine()

    public struct DiffResult: Sendable {
        public let archive1URL: URL
        public let archive2URL: URL
        public let addedItems: [ArchiveItem]     // Arşiv 2'de yeni eklenenler
        public let removedItems: [ArchiveItem]   // Arşiv 1'de olup 2'de silinenler
        public let modifiedItems: [(item1: ArchiveItem, item2: ArchiveItem)] // Boyutu/CRC'si değişenler
        public let unchangedItems: [ArchiveItem] // Birebir aynı kalanlar

        public var totalDifferences: Int {
            addedItems.count + removedItems.count + modifiedItems.count
        }
    }

    private init() {}

    /// İki arşivi asenkron olarak karşılaştırır
    public func compareArchives(archive1URL: URL, archive2URL: URL) async throws -> DiffResult {
        let (items1, _) = try await ArchiveManager.shared.openArchive(at: archive1URL)
        let (items2, _) = try await ArchiveManager.shared.openArchive(at: archive2URL)

        var map1: [String: ArchiveItem] = [:]
        for item in items1 {
            map1[item.path] = item
        }

        var map2: [String: ArchiveItem] = [:]
        for item in items2 {
            map2[item.path] = item
        }

        var added: [ArchiveItem] = []
        var removed: [ArchiveItem] = []
        var modified: [(ArchiveItem, ArchiveItem)] = []
        var unchanged: [ArchiveItem] = []

        // Arşiv 2'deki öğeleri kontrol et
        for (path, item2) in map2 {
            if let item1 = map1[path] {
                // Her ikisinde de var: boyut veya CRC farklı mı?
                let sizeDiff = item1.uncompressedSize != item2.uncompressedSize
                let crcDiff = (item1.crc32 != nil && item2.crc32 != nil && item1.crc32 != item2.crc32)

                if sizeDiff || crcDiff {
                    modified.append((item1, item2))
                } else {
                    unchanged.append(item2)
                }
            } else {
                // Yalnızca 2'de var -> Eklenmiş
                added.append(item2)
            }
        }

        // Arşiv 1'de olup 2'de olmayanlar -> Silinmiş
        for (path, item1) in map1 {
            if map2[path] == nil {
                removed.append(item1)
            }
        }

        return DiffResult(
            archive1URL: archive1URL,
            archive2URL: archive2URL,
            addedItems: added.sorted(by: { $0.path < $1.path }),
            removedItems: removed.sorted(by: { $0.path < $1.path }),
            modifiedItems: modified.sorted(by: { $0.0.path < $1.0.path }),
            unchangedItems: unchanged.sorted(by: { $0.path < $1.path })
        )
    }
}
