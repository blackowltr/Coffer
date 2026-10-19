import SwiftUI
import AppKit

/// WinRAR tarzı tam donanımlı Arşiv Gezgini Görünümü (Explorer Mode, Drag Out, Multi-part ve Quick Look destekli)
public struct ArchiveBrowserView: View {
    @ObservedObject private var settings = AppSettings.shared
    public let archiveURL: URL?
    public let items: [ArchiveItem]
    public let metadata: ArchiveMetadata?
    @Binding public var currentPath: String
    @Binding public var searchText: String
    @Binding public var selectedItemIDs: Set<UUID>

    public let onAddFiles: () -> Void
    public let onExtract: () -> Void
    public let onTestArchive: () -> Void
    public let onPreviewItem: (ArchiveItem) -> Void
    public let onDeleteSelected: () -> Void
    public let onCleanMacJunk: () -> Void
    public let onShowInfo: () -> Void
    public let onConvertArchive: () -> Void
    public let onDiffArchive: () -> Void
    public let onLockArchive: () -> Void
    public let onRepairArchive: () -> Void
    public let onNavigateTo: (String) -> Void
    public let onNavigateUp: () -> Void
    public var securityReport: ArchiveSecurityReport? = nil
    public var onShowSecurity: (() -> Void)? = nil
    public var onNewArchive: (() -> Void)? = nil

    public init(
        archiveURL: URL?,
        items: [ArchiveItem],
        metadata: ArchiveMetadata?,
        currentPath: Binding<String>,
        searchText: Binding<String>,
        selectedItemIDs: Binding<Set<UUID>>,
        onAddFiles: @escaping () -> Void,
        onExtract: @escaping () -> Void,
        onTestArchive: @escaping () -> Void,
        onPreviewItem: @escaping (ArchiveItem) -> Void,
        onDeleteSelected: @escaping () -> Void,
        onCleanMacJunk: @escaping () -> Void,
        onShowInfo: @escaping () -> Void,
        onConvertArchive: @escaping () -> Void,
        onDiffArchive: @escaping () -> Void,
        onLockArchive: @escaping () -> Void,
        onRepairArchive: @escaping () -> Void,
        onNavigateTo: @escaping (String) -> Void,
        onNavigateUp: @escaping () -> Void,
        securityReport: ArchiveSecurityReport? = nil,
        onShowSecurity: (() -> Void)? = nil,
        onNewArchive: (() -> Void)? = nil
    ) {
        self.archiveURL = archiveURL
        self.items = items
        self.metadata = metadata
        self._currentPath = currentPath
        self._searchText = searchText
        self._selectedItemIDs = selectedItemIDs
        self.onAddFiles = onAddFiles
        self.onExtract = onExtract
        self.onTestArchive = onTestArchive
        self.onPreviewItem = onPreviewItem
        self.onDeleteSelected = onDeleteSelected
        self.onCleanMacJunk = onCleanMacJunk
        self.onShowInfo = onShowInfo
        self.onConvertArchive = onConvertArchive
        self.onDiffArchive = onDiffArchive
        self.onLockArchive = onLockArchive
        self.onRepairArchive = onRepairArchive
        self.onNavigateTo = onNavigateTo
        self.onNavigateUp = onNavigateUp
        self.securityReport = securityReport
        self.onShowSecurity = onShowSecurity
        self.onNewArchive = onNewArchive
    }

    @State private var cachedDirectories: [ArchiveDirectoryItem] = []
    @State private var cachedCategoryCounts: [ArchiveCategoryFilter: Int] = [:]
    @State private var activeCategoryFilter: ArchiveCategoryFilter? = nil
    @State private var multiPartInfo: MultiPartVolumeInfo? = nil

    private var junkItemsCount: Int {
        items.filter { AppleJunkSanitizer.shared.isJunk(path: $0.path) }.count
    }

    private var selectedSize: Int64 {
        items.filter { selectedItemIDs.contains($0.id) }
            .reduce(0) { $0 + $1.uncompressedSize }
    }

    private var visibleItems: [ArchiveItem] {
        let baseItems = AppSettings.shared.stripMacJunkFiles ? items.filter { !AppleJunkSanitizer.shared.isJunk(path: $0.path) } : items

        if !searchText.isEmpty {
            return baseItems.filter {
                $0.path.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let filter = activeCategoryFilter {
            let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "gif", "svg", "bmp", "tiff", "ico"]
            let docExts: Set<String> = ["pdf", "doc", "docx", "pages", "txt", "rtf", "md", "xls", "xlsx", "numbers", "csv", "ppt", "pptx", "key"]
            let mediaExts: Set<String> = ["mp4", "mov", "mkv", "avi", "webm", "m4v", "mp3", "m4a", "flac", "wav", "aac", "ogg"]
            let codeExts: Set<String> = ["swift", "c", "cpp", "h", "hpp", "py", "js", "ts", "html", "css", "json", "xml", "sh", "yaml", "yml", "sql"]

            return baseItems.filter { item in
                guard !item.isDirectory else { return false }
                let ext = item.fileExtension
                switch filter {
                case .images: return imageExts.contains(ext)
                case .documents: return docExts.contains(ext)
                case .media: return mediaExts.contains(ext)
                case .code: return codeExts.contains(ext)
                }
            }
        }

        if currentPath.isEmpty {
            return baseItems.filter { !$0.path.contains("/") }
        } else {
            let prefix = currentPath + "/"
            return baseItems.filter { item in
                guard item.path.hasPrefix(prefix) else { return false }
                let remainder = item.path.dropFirst(prefix.count)
                return !remainder.contains("/")
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Üst Eylem Araç Çubuğu (Toolbar)
            HStack(spacing: 6) {
                if let onNew = onNewArchive {
                    WinRARToolbarButton(title: "Sıkıştır", icon: "plus.circle.fill", color: settings.accentColorChoice.color, action: onNew)
                }
                WinRARToolbarButton(title: "Dizine Çıkart", icon: "arrow.down.doc.fill", color: .cyan, action: onExtract)
                WinRARToolbarButton(title: "Dosya Ekle", icon: "plus.doc.fill", color: .green, action: onAddFiles)
                WinRARToolbarButton(title: "Test Et", icon: "checkmark.shield.fill", color: .purple, action: onTestArchive)

                // Quick Look Önizleme Butonu
                WinRARToolbarButton(title: "Önizle", icon: "eye.fill", color: .indigo) {
                    if let firstID = selectedItemIDs.first, let item = items.first(where: { $0.id == firstID }), !item.isDirectory {
                        onPreviewItem(item)
                    } else if let firstFile = items.first(where: { !$0.isDirectory }) {
                        selectedItemIDs = [firstFile.id]
                        onPreviewItem(firstFile)
                    }
                }

                WinRARToolbarButton(title: "Sil", icon: "trash.fill", color: .red, action: onDeleteSelected)

                Divider().frame(height: 18)

                WinRARToolbarButton(title: "Dönüştür", icon: "arrow.triangle.2.circlepath", color: settings.accentColorChoice.color, action: onConvertArchive)
                WinRARToolbarButton(title: "Farklar", icon: "arrow.left.arrow.right", color: .teal, action: onDiffArchive)
                WinRARToolbarButton(title: "Bilgi", icon: "info.circle.fill", color: .cyan, action: onShowInfo)
                WinRARToolbarButton(title: "Kilitle", icon: "lock.shield.fill", color: .pink, action: onLockArchive)
                WinRARToolbarButton(title: "Onar", icon: "wrench.and.screwdriver.fill", color: .indigo, action: onRepairArchive)
                WinRARToolbarButton(title: "Güvenlik", icon: "shield.lefthalf.filled", color: .red) {
                    onShowSecurity?()
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            // Güvenlik & Risk Tespit Bandı
            if let sec = securityReport, sec.riskLevel != .safe {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: sec.riskLevel.systemIcon)
                        .foregroundColor(sec.riskLevel == .danger ? .red : .orange)
                        .font(.system(size: 13, weight: .bold))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Güvenlik Uyarısı (Skor: \(sec.safetyScore)/100 - \(sec.riskLevel.rawValue))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(sec.riskLevel == .danger ? .red : .orange)
                        Text(sec.findings.first?.title ?? "Şüpheli dosya veya parametreler saptandı.")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: { onShowSecurity?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass.shield.fill")
                            Text("Analizi İncele")
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sec.riskLevel == .danger ? .red : .orange)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background((sec.riskLevel == .danger ? Color.red : Color.orange).opacity(0.10))
            }

            // Çok Parçalı Arşiv Tespit Bandı
            if let mp = multiPartInfo, mp.isMultiPart {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: mp.isComplete ? "square.split.2x1.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(mp.isComplete ? .indigo : .red)
                        .font(.system(size: 12))

                    Text(mp.summaryDescription)
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    if !mp.isComplete {
                        Button("Klasörü Tara...") {
                            if let url = archiveURL {
                                multiPartInfo = MultiPartVolumeManager.shared.analyzeArchive(at: url)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(mp.isComplete ? Color.indigo.opacity(0.10) : Color.red.opacity(0.12))
            }

            // macOS Artıkları Tespit Uyarısı & Hızlı Temizlik Bandı
            if junkItemsCount > 0 {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.mint)
                        .font(.system(size: 12))

                    Text("Bu arşivde \(junkItemsCount) adet macOS/sistem artığı (.DS_Store, __MACOSX, ._*) tespit edildi.")
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    Button(action: onCleanMacJunk) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.slash.fill")
                            Text("Artıkları Şimdi Temizle")
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.mint.opacity(0.12))
            }

            Divider()

            // 2. Yol & Arama Çubuğu (Breadcrumb)
            BreadcrumbBar(
                archiveName: archiveURL?.lastPathComponent ?? "Arşiv",
                currentPath: activeCategoryFilter != nil ? (activeCategoryFilter!.rawValue) : currentPath,
                searchText: $searchText,
                onNavigateTo: { path in
                    activeCategoryFilter = nil
                    onNavigateTo(path)
                },
                onNavigateUp: {
                    activeCategoryFilter = nil
                    onNavigateUp()
                }
            )

            Divider()

            // 3. Dosya Listesi & Klasör Ağacı
            HSplitView {
                ArchiveSidebarView(
                    archiveName: archiveURL?.lastPathComponent ?? "Arşiv",
                    directories: cachedDirectories,
                    totalItemsCount: items.count,
                    categoryCounts: cachedCategoryCounts,
                    currentPath: currentPath,
                    activeCategoryFilter: activeCategoryFilter,
                    onSelectDirectory: { path in
                        activeCategoryFilter = nil
                        onNavigateTo(path)
                    },
                    onSelectCategory: { filter in
                        activeCategoryFilter = filter
                    }
                )
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)

                ArchiveTableView(
                    items: visibleItems,
                    selectedItemIDs: $selectedItemIDs,
                    onOpenDirectory: { path in
                        activeCategoryFilter = nil
                        onNavigateTo(path)
                    },
                    onOpenFile: { item in
                        Task {
                            guard let arcURL = archiveURL else { return }
                            if let extractedURL = try? await ArchiveManager.shared.extractItemForPreview(archiveURL: arcURL, item: item) {
                                await MainActor.run {
                                    _ = NSWorkspace.shared.open(extractedURL)
                                }
                            }
                        }
                    },
                    onPreviewItem: onPreviewItem,
                    onExtractSelected: onExtract,
                    onDragItem: { item in
                        guard let arcURL = archiveURL else { return nil }
                        if let localURL = ArchiveManager.shared.extractItemSynchronouslyForDrag(archiveURL: arcURL, item: item) {
                            let provider = NSItemProvider(item: localURL as NSSecureCoding, typeIdentifier: "public.file-url")
                            provider.suggestedName = item.name
                            return provider
                        }
                        return nil
                    }
                )
            }

            // 4. Durum Çubuğu (Footer)
            ArchiveFooterBar(
                totalItemsCount: visibleItems.count,
                totalUncompressedSize: metadata?.totalUncompressedSize ?? 0,
                selectedItemsCount: selectedItemIDs.count,
                selectedSize: selectedSize,
                savingsRatio: metadata?.overallSavingsRatio ?? 0,
                metadata: metadata
            )
        }
        .onAppear {
            rebuildDirectoryCache()
            if let url = archiveURL {
                multiPartInfo = MultiPartVolumeManager.shared.analyzeArchive(at: url)
            }
        }
        .onChange(of: items.count) { _, _ in
            rebuildDirectoryCache()
            if let url = archiveURL {
                multiPartInfo = MultiPartVolumeManager.shared.analyzeArchive(at: url)
            }
        }
    }

    private func rebuildDirectoryCache() {
        let cleanItems = AppSettings.shared.stripMacJunkFiles ? items.filter { !AppleJunkSanitizer.shared.isJunk(path: $0.path) } : items
        cachedDirectories = ArchiveDirectoryItem.buildDirectoryList(from: cleanItems)
        cachedCategoryCounts = ArchiveDirectoryItem.calculateCategoryCounts(from: cleanItems)
    }
}
