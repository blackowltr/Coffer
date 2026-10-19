import Foundation

/// Arşiv içerisindeki bir klasörün önbelleğe alınmış metadata düğümü
public struct ArchiveDirectoryItem: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let path: String               // Örn: "Belgeler/Raporlar"
    public let name: String               // Örn: "Raporlar"
    public let parentPath: String         // Örn: "Belgeler" (veya kök için "")
    public let ancestorPaths: [String]    // Örn: ["Belgeler"]
    public let depth: Int                 // Derinlik (0 = Kök altı, 1 = 1. seviye alt vb.)
    public let directItemCount: Int       // Doğrudan bu klasörün içindeki öğe sayısı
    public let totalItemCount: Int        // Tüm alt klasörlerle birlikte toplam öğe sayısı
    public let hasSubdirectories: Bool    // Altında en az bir alt klasör var mı?

    public init(
        path: String,
        name: String,
        parentPath: String,
        ancestorPaths: [String] = [],
        depth: Int,
        directItemCount: Int,
        totalItemCount: Int,
        hasSubdirectories: Bool
    ) {
        self.path = path
        self.name = name
        self.parentPath = parentPath
        self.ancestorPaths = ancestorPaths
        self.depth = depth
        self.directItemCount = directItemCount
        self.totalItemCount = totalItemCount
        self.hasSubdirectories = hasSubdirectories
    }
}

/// Arşiv içeriği için akıllı filtreleme kategorileri
public enum ArchiveCategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case images = "Görseller"
    case documents = "Belgeler"
    case media = "Medya"
    case code = "Kod & Veri"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .images: return "photo.on.rectangle.fill"
        case .documents: return "doc.richtext.fill"
        case .media: return "film.stack.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

extension ArchiveDirectoryItem {
    /// O(N) tek geçişte tüm arşiv dizin ağacını ve öğe sayılarını oluşturur
    public static func buildDirectoryList(from items: [ArchiveItem]) -> [ArchiveDirectoryItem] {
        guard !items.isEmpty else { return [] }

        var allDirPaths = Set<String>()
        var directCounts: [String: Int] = [:]
        var totalCounts: [String: Int] = [:]

        for item in items {
            // macOS artıklarını atla
            if AppleJunkSanitizer.shared.isJunk(path: item.path) { continue }

            if item.isDirectory && !item.path.isEmpty {
                allDirPaths.insert(item.path)
            }
            if !item.parentPath.isEmpty {
                let parts = item.parentPath.split(separator: "/").map(String.init)
                var current = ""
                for part in parts {
                    current = current.isEmpty ? part : "\(current)/\(part)"
                    allDirPaths.insert(current)
                    if !item.isDirectory {
                        totalCounts[current, default: 0] += 1
                    }
                }
            }
            if !item.isDirectory {
                directCounts[item.parentPath, default: 0] += 1
            }
        }

        // Dizinleri hiyerarşik ağaç sırasına (Depth-First Pre-order) göre sırala:
        // Ebeveyn klasörün doğrudan alt klasörleri hemen onun altında listelenir.
        var childrenMap: [String: [String]] = [:]
        var rootDirs: [String] = []

        for dirPath in allDirPaths {
            let components = dirPath.split(separator: "/").map(String.init)
            if components.count > 1 {
                let parent = components.dropLast().joined(separator: "/")
                childrenMap[parent, default: []].append(dirPath)
            } else {
                rootDirs.append(dirPath)
            }
        }

        rootDirs.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        for parent in childrenMap.keys {
            childrenMap[parent]?.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        }

        var orderedPaths: [String] = []
        func traverse(_ path: String) {
            orderedPaths.append(path)
            if let children = childrenMap[path] {
                for child in children {
                    traverse(child)
                }
            }
        }

        for root in rootDirs {
            traverse(root)
        }

        return orderedPaths.map { path in
            let components = path.split(separator: "/").map(String.init)
            let name = components.last ?? path
            let depth = max(0, components.count - 1)
            let parent = components.count > 1 ? components.dropLast().joined(separator: "/") : ""
            let direct = directCounts[path, default: 0]
            let total = totalCounts[path, default: direct]
            let hasSubs = !(childrenMap[path]?.isEmpty ?? true)

            var ancestors: [String] = []
            var cur = ""
            for part in components.dropLast() {
                cur = cur.isEmpty ? part : "\(cur)/\(part)"
                ancestors.append(cur)
            }

            return ArchiveDirectoryItem(
                path: path,
                name: name,
                parentPath: parent,
                ancestorPaths: ancestors,
                depth: depth,
                directItemCount: direct,
                totalItemCount: total,
                hasSubdirectories: hasSubs
            )
        }
    }

    /// Kategori bazlı dosya adetlerini tek seferde hesaplar
    public static func calculateCategoryCounts(from items: [ArchiveItem]) -> [ArchiveCategoryFilter: Int] {
        var counts: [ArchiveCategoryFilter: Int] = [
            .images: 0,
            .documents: 0,
            .media: 0,
            .code: 0
        ]

        let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "bmp", "tiff", "ico"]
        let docExts: Set<String> = ["pdf", "doc", "docx", "pages", "txt", "rtf", "md", "xls", "xlsx", "numbers", "csv", "ppt", "pptx", "key"]
        let mediaExts: Set<String> = ["mp4", "mov", "mkv", "avi", "webm", "m4v", "mp3", "m4a", "flac", "wav", "aac", "ogg"]
        let codeExts: Set<String> = ["swift", "c", "cpp", "h", "hpp", "py", "js", "ts", "html", "css", "json", "xml", "sh", "yaml", "yml", "sql"]

        for item in items where !item.isDirectory {
            let ext = item.fileExtension
            if imageExts.contains(ext) { counts[.images, default: 0] += 1 }
            else if docExts.contains(ext) { counts[.documents, default: 0] += 1 }
            else if mediaExts.contains(ext) { counts[.media, default: 0] += 1 }
            else if codeExts.contains(ext) { counts[.code, default: 0] += 1 }
        }

        return counts
    }
}
