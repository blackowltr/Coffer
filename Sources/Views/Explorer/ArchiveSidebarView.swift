import SwiftUI

/// Apple macOS Human Interface Guidelines standartlarında, yüksek performanslı ve akıcı Arşiv Kenar Çubuğu
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
    @State private var visibleDirectoriesCache: [ArchiveDirectoryItem] = []
    @State private var isFoldersSectionExpanded: Bool = true
    @State private var isFiltersSectionExpanded: Bool = true

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

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Klasörler İçinde Hızlı Arama Kutusu (Arama Çubuğu)
            if directories.count > 3 {
                searchBarView
            }

            // 2. Ana Kaydırılabilir İçerik
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    // Bölüm 1: Ana Konum (Kök Dizin)
                    locationSection

                    // Bölüm 2: Akıllı Dosya Filtreleri
                    let availableCategories = ArchiveCategoryFilter.allCases.filter { (categoryCounts[$0] ?? 0) > 0 }
                    if !availableCategories.isEmpty {
                        smartFiltersSection(categories: availableCategories)
                    }

                    // Bölüm 3: Hiyerarşik Klasör Ağacı
                    if !directories.isEmpty {
                        folderTreeSection
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.65))
        .onAppear {
            expandAncestors(of: currentPath)
            recalculateVisibleDirectories()
        }
        .onChange(of: currentPath) { _, newPath in
            expandAncestors(of: newPath)
            recalculateVisibleDirectories()
        }
        .onChange(of: directoryFilterText) { _, _ in
            recalculateVisibleDirectories()
        }
        .onChange(of: directories) { _, _ in
            recalculateVisibleDirectories()
        }
    }

    // MARK: - 1. Klasör Arama Çubuğu
    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Klasörlerde ara...", text: $directoryFilterText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundColor(.primary)

            if !directoryFilterText.isEmpty {
                Button(action: { directoryFilterText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
        )
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - 2. Ana Konum (Kök Dizin)
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeaderLabel("KONUM", icon: "location.fill")

            let isRootSelected = currentPath.isEmpty && activeCategoryFilter == nil
            Button(action: {
                onSelectCategory(nil)
                onSelectDirectory("")
            }) {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accentColor.opacity(isRootSelected ? 0.9 : 0.15))
                            .frame(width: 22, height: 22)

                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isRootSelected ? .white : accentColor)
                    }

                    Text(archiveName.isEmpty ? "Ana Dizin" : archiveName)
                        .font(.system(size: 12, weight: isRootSelected ? .semibold : .medium))
                        .foregroundColor(isRootSelected ? .primary : .primary.opacity(0.92))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    countBadgeView(count: totalItemsCount, isSelected: isRootSelected)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectionBackground(isSelected: isRootSelected))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 3. Dosya Filtreleri Bölümü
    private func smartFiltersSection(categories: [ArchiveCategoryFilter]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionHeaderLabel("KATEGORİLER", icon: "line.3.horizontal.decrease.circle")

                Spacer()

                Button(action: {
                    withAnimation(settings.enableAnimations ? .spring(response: 0.25, dampingFraction: 0.8) : nil) {
                        isFiltersSectionExpanded.toggle()
                    }
                }) {
                    Image(systemName: isFiltersSectionExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
            }

            if isFiltersSectionExpanded {
                VStack(spacing: 2) {
                    ForEach(categories) { cat in
                        let count = categoryCounts[cat] ?? 0
                        let isCatSelected = activeCategoryFilter == cat

                        Button(action: {
                            onSelectCategory(cat)
                        }) {
                            HStack(spacing: 9) {
                                // Renkli Kategori İkonu
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(categoryColor(cat).opacity(isCatSelected ? 0.9 : 0.14))
                                        .frame(width: 22, height: 22)

                                    Image(systemName: cat.iconName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(isCatSelected ? .white : categoryColor(cat))
                                }

                                Text(cat.rawValue)
                                    .font(.system(size: 12, weight: isCatSelected ? .semibold : .medium))
                                    .foregroundColor(isCatSelected ? .primary : .primary.opacity(0.88))
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                countBadgeView(count: count, isSelected: isCatSelected)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectionBackground(isSelected: isCatSelected))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 4. Klasör Ağacı Bölümü
    private var folderTreeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionHeaderLabel("KLASÖRLER (\(directories.count))", icon: "folder.fill")

                Spacer()

                // Tümünü Genişlet / Daralt Düğmesi
                if directories.contains(where: { $0.hasSubdirectories }) {
                    Button(action: toggleExpandAll) {
                        Image(systemName: expandedFolderPaths.isEmpty ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(expandedFolderPaths.isEmpty ? "Tüm Klasörleri Genişlet" : "Tüm Klasörleri Daralt")
                }
            }

            if !visibleDirectoriesCache.isEmpty {
                VStack(spacing: 2) {
                    ForEach(visibleDirectoriesCache, id: \.path) { dir in
                        folderRowView(dir: dir)
                    }
                }
            } else if !directoryFilterText.isEmpty {
                Text("Eşleşen klasör bulunamadı")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
    }

    // MARK: - 5. Klasör Satırı Görünümü
    private func folderRowView(dir: ArchiveDirectoryItem) -> some View {
        let isDirSelected = currentPath == dir.path && activeCategoryFilter == nil
        let isExpanded = expandedFolderPaths.contains(dir.path)

        return HStack(spacing: 2) {
            // Derinlik Girintisi (Ağaç Hiyerarşisi)
            if dir.depth > 0 {
                Spacer().frame(width: CGFloat(min(dir.depth, 6) * 12))
            }

            // Açılır / Kapanır Ok (Chevron)
            if dir.hasSubdirectories {
                Button(action: { toggleFolder(dir.path) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 14, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 14, height: 16)
            }

            // Klasör Butonu
            Button(action: {
                onSelectCategory(nil)
                onSelectDirectory(dir.path)
                if dir.hasSubdirectories && !isExpanded {
                    toggleFolder(dir.path)
                }
            }) {
                HStack(spacing: 7) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(isDirSelected ? accentColor : Color.secondary.opacity(0.85))
                        .font(.system(size: 12.5))
                        .frame(width: 16)

                    Text(dir.name)
                        .font(.system(size: 12, weight: isDirSelected ? .semibold : .regular))
                        .foregroundColor(isDirSelected ? .primary : .primary.opacity(0.88))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if dir.totalItemCount > 0 {
                        countBadgeView(count: dir.totalItemCount, isSelected: isDirSelected)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4.5)
        .background(selectionBackground(isSelected: isDirSelected))
    }

    // MARK: - 6. Performans: Önbellek Yeniden Hesaplama
    private func recalculateVisibleDirectories() {
        let cleanQuery = directoryFilterText.trimmingCharacters(in: .whitespaces)
        if !cleanQuery.isEmpty {
            self.visibleDirectoriesCache = directories.filter {
                $0.name.localizedCaseInsensitiveContains(cleanQuery)
            }
            return
        }

        var visible: [ArchiveDirectoryItem] = []
        visible.reserveCapacity(directories.count)

        for dir in directories {
            if dir.depth == 0 {
                visible.append(dir)
                continue
            }

            var allAncestorsExpanded = true
            for ancestor in dir.ancestorPaths {
                if !expandedFolderPaths.contains(ancestor) {
                    allAncestorsExpanded = false
                    break
                }
            }

            if allAncestorsExpanded {
                visible.append(dir)
            }
        }

        self.visibleDirectoriesCache = visible
    }

    // MARK: - 7. Yardımcı Görsel Bileşenler
    private func sectionHeaderLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))

            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func countBadgeView(count: Int, isSelected: Bool) -> some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(isSelected ? .primary : .secondary.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(isSelected ? Color.primary.opacity(0.12) : Color(NSColor.quaternaryLabelColor).opacity(0.6))
            )
    }

    private func selectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? accentColor.opacity(0.16) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
    }

    private func categoryColor(_ cat: ArchiveCategoryFilter) -> Color {
        switch cat {
        case .images: return .purple
        case .documents: return .orange
        case .media: return .pink
        case .code: return .teal
        }
    }

    // MARK: - 8. Klasör Açma/Kapama Mantığı
    private func toggleFolder(_ path: String) {
        withAnimation(settings.enableAnimations ? .spring(response: 0.25, dampingFraction: 0.8) : nil) {
            if expandedFolderPaths.contains(path) {
                expandedFolderPaths.remove(path)
            } else {
                expandedFolderPaths.insert(path)
            }
            recalculateVisibleDirectories()
        }
    }

    private func toggleExpandAll() {
        withAnimation(settings.enableAnimations ? .spring(response: 0.28, dampingFraction: 0.8) : nil) {
            if expandedFolderPaths.isEmpty {
                let pathsWithChildren = directories.filter { $0.hasSubdirectories }.map { $0.path }
                expandedFolderPaths = Set(pathsWithChildren)
            } else {
                expandedFolderPaths.removeAll()
            }
            recalculateVisibleDirectories()
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
}
