import SwiftUI

/// Yüksek performanslı, Finder tarzı akıllı açılır/kapanır (Accordion Tree) Arşiv Kenar Çubuğu
public struct ArchiveSidebarView: View {
    @ObservedObject private var settings = AppSettings.shared

    public let archiveName: String
    public let directories: [ArchiveDirectoryItem]
    public let totalItemsCount: Int
    public let categoryCounts: [ArchiveCategoryFilter: Int]
    public let currentPath: String
    public let activeCategoryFilter: ArchiveCategoryFilter?
    public let onSelectDirectory: (String) -> Void
    public let onSelectCategory: (ArchiveCategoryFilter?) -> Void

    @State private var directoryFilterText: String = ""
    @State private var expandedFolderPaths: Set<String> = []

    public init(
        archiveName: String,
        directories: [ArchiveDirectoryItem],
        totalItemsCount: Int,
        categoryCounts: [ArchiveCategoryFilter: Int],
        currentPath: String,
        activeCategoryFilter: ArchiveCategoryFilter?,
        onSelectDirectory: @escaping (String) -> Void,
        onSelectCategory: @escaping (ArchiveCategoryFilter?) -> Void
    ) {
        self.archiveName = archiveName
        self.directories = directories
        self.totalItemsCount = totalItemsCount
        self.categoryCounts = categoryCounts
        self.currentPath = currentPath
        self.activeCategoryFilter = activeCategoryFilter
        self.onSelectDirectory = onSelectDirectory
        self.onSelectCategory = onSelectCategory
    }

    /// Yalnızca ebeveynleri açık olan veya arama kriterine uyan klasörleri gösterir (Açılır/Kapanır Mantık)
    private var visibleDirectories: [ArchiveDirectoryItem] {
        if !directoryFilterText.trimmingCharacters(in: .whitespaces).isEmpty {
            return directories.filter { $0.name.localizedCaseInsensitiveContains(directoryFilterText) }
        }

        return directories.filter { isDirectoryVisible($0) }
    }

    private func isDirectoryVisible(_ dir: ArchiveDirectoryItem) -> Bool {
        if dir.depth == 0 { return true }
        for ancestor in dir.ancestorPaths {
            if !expandedFolderPaths.contains(ancestor) {
                return false
            }
        }
        return true
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Hızlı Klasör Arama Çubuğu (Eğer 4'ten fazla klasör varsa)
            if directories.count > 4 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    TextField("Klasörlerde ara...", text: $directoryFilterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))

                    if !directoryFilterText.isEmpty {
                        Button(action: { directoryFilterText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(7)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    // 1. Kök Dizin (Ana Arşiv)
                    sectionHeader("KONUM")

                    let isRootSelected = currentPath.isEmpty && activeCategoryFilter == nil
                    Button(action: {
                        onSelectCategory(nil)
                        onSelectDirectory("")
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(settings.accentColorChoice.color)
                                .font(.system(size: 13))
                                .frame(width: 16)

                            Text(archiveName.isEmpty ? "Ana Dizin" : archiveName)
                                .font(.system(size: 12, weight: isRootSelected ? .semibold : .regular))
                                .foregroundColor(isRootSelected ? .primary : .primary.opacity(0.9))
                                .lineLimit(1)

                            Spacer()

                            countBadge("\(totalItemsCount)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(rowBackground(isSelected: isRootSelected))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    // 2. Akıllı Filtreler (Varsa)
                    let availableCategories = ArchiveCategoryFilter.allCases.filter { (categoryCounts[$0] ?? 0) > 0 }
                    if !availableCategories.isEmpty {
                        sectionHeader("AKILLI FİLTRELER")
                            .padding(.top, 8)

                        ForEach(availableCategories) { cat in
                            let count = categoryCounts[cat] ?? 0
                            let isCatSelected = activeCategoryFilter == cat

                            Button(action: {
                                onSelectCategory(cat)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: cat.iconName)
                                        .foregroundColor(isCatSelected ? settings.accentColorChoice.color : .secondary)
                                        .font(.system(size: 12))
                                        .frame(width: 16)

                                    Text(cat.rawValue)
                                        .font(.system(size: 12, weight: isCatSelected ? .semibold : .regular))
                                        .foregroundColor(isCatSelected ? .primary : .primary.opacity(0.9))
                                        .lineLimit(1)

                                    Spacer()

                                    countBadge("\(count)")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(rowBackground(isSelected: isCatSelected))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 3. Açılır/Kapanır Klasörler Ağacı
                    if !visibleDirectories.isEmpty {
                        HStack {
                            sectionHeader("KLASÖRLER (\(directories.count))")
                            Spacer()

                            // Tümünü Genişlet / Daralt Butonu
                            if directories.contains(where: { $0.hasSubdirectories }) {
                                Button(action: toggleExpandAll) {
                                    Image(systemName: expandedFolderPaths.isEmpty ? "chevron.down.circle" : "chevron.up.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(expandedFolderPaths.isEmpty ? "Tüm Klasörleri Genişlet" : "Tüm Klasörleri Daralt")
                                .padding(.trailing, 8)
                            }
                        }
                        .padding(.top, 8)

                        ForEach(visibleDirectories) { dir in
                            let isDirSelected = currentPath == dir.path && activeCategoryFilter == nil
                            let isExpanded = expandedFolderPaths.contains(dir.path)

                            HStack(spacing: 4) {
                                // Ağaç derinliğine göre girinti
                                if dir.depth > 0 {
                                    Spacer().frame(width: CGFloat(min(dir.depth, 5) * 14))
                                }

                                // Açılır/Kapanır Chevron Oku
                                if dir.hasSubdirectories {
                                    Button(action: { toggleFolder(dir.path) }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                            .frame(width: 14, height: 14)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Spacer().frame(width: 14, height: 14)
                                }

                                // Klasör Satırı İçeriği
                                Button(action: {
                                    onSelectCategory(nil)
                                    onSelectDirectory(dir.path)
                                    // Alt klasörü varsa ve kapalıysa otomatik aç
                                    if dir.hasSubdirectories && !isExpanded {
                                        toggleFolder(dir.path)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isExpanded ? "folder.fill" : (isDirSelected ? "folder.fill" : "folder"))
                                            .foregroundColor(isDirSelected ? settings.accentColorChoice.color : .secondary)
                                            .font(.system(size: 12))
                                            .frame(width: 14)

                                        Text(dir.name)
                                            .font(.system(size: 12, weight: isDirSelected ? .semibold : .regular))
                                            .foregroundColor(isDirSelected ? .primary : .primary.opacity(0.9))
                                            .lineLimit(1)

                                        Spacer()

                                        if dir.totalItemCount > 0 {
                                            countBadge("\(dir.totalItemCount)")
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rowBackground(isSelected: isDirSelected))
                            .cornerRadius(6)
                        }
                    } else if !directories.isEmpty && !directoryFilterText.isEmpty {
                        Text("Eşleşen klasör bulunamadı")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            expandAncestors(of: currentPath)
        }
        .onChange(of: currentPath) { _, newPath in
            expandAncestors(of: newPath)
        }
    }

    // MARK: - Klasör Açma / Kapama Mantığı

    private func toggleFolder(_ path: String) {
        withAnimation(settings.enableAnimations ? .spring(response: 0.28, dampingFraction: 0.8) : nil) {
            if expandedFolderPaths.contains(path) {
                expandedFolderPaths.remove(path)
            } else {
                expandedFolderPaths.insert(path)
            }
        }
    }

    private func toggleExpandAll() {
        withAnimation(settings.enableAnimations ? .spring(response: 0.3) : nil) {
            if expandedFolderPaths.isEmpty {
                let pathsWithChildren = directories.filter { $0.hasSubdirectories }.map { $0.path }
                expandedFolderPaths = Set(pathsWithChildren)
            } else {
                expandedFolderPaths.removeAll()
            }
        }
    }

    private func expandAncestors(of path: String) {
        guard !path.isEmpty else { return }
        let parts = path.split(separator: "/").map(String.init)
        var current = ""
        for part in parts.dropLast() {
            current = current.isEmpty ? part : "\(current)/\(part)"
            expandedFolderPaths.insert(current)
        }
    }

    // MARK: - Yardımcı Görünümler

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private func countBadge(_ countStr: String) -> some View {
        Text(countStr)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(NSColor.quaternaryLabelColor))
            .cornerRadius(10)
    }

    private func rowBackground(isSelected: Bool) -> some View {
        Group {
            if isSelected {
                settings.accentColorChoice.color.opacity(0.16)
            } else {
                Color.clear
            }
        }
    }
}
