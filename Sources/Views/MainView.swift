import SwiftUI
import UniformTypeIdentifiers
import AppKit

public enum AppMode: String, CaseIterable, Identifiable {
    case explorer = "Gezgin Modu"
    case quickDrop = "Hızlı Mod"

    public var id: String { rawValue }
}

public enum ActiveSheet: Identifiable {
    case compress(sources: [URL])
    case extract
    case password(archiveName: String)
    case info(metadata: ArchiveMetadata)
    case testResult(result: ArchiveTestResult)
    case settings
    case diff(initialURL: URL?)
    case convert(sourceURL: URL)
    case repair(archiveURL: URL)
    case security(report: ArchiveSecurityReport)
    case conflict(fileName: String)

    public var id: String {
        switch self {
        case .compress: return "compress"
        case .extract: return "extract"
        case .password: return "password"
        case .info: return "info"
        case .testResult: return "testResult"
        case .settings: return "settings"
        case .diff: return "diff"
        case .convert: return "convert"
        case .repair: return "repair"
        case .security: return "security"
        case .conflict: return "conflict"
        }
    }
}

public struct MainView: View {
    @ObservedObject private var settings = AppSettings.shared

    @State private var currentMode: AppMode = .explorer
    @State private var openedArchiveURL: URL? = nil
    @State private var archiveItems: [ArchiveItem] = []
    @State private var archiveMetadata: ArchiveMetadata? = nil
    @State private var currentPath: String = ""
    @State private var searchText: String = ""
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var isWindowDropTargeted: Bool = false

    // Diyalog ve Modal Durumları (Tekil ActiveSheet Modeli ile Çakışmasız)
    @State private var activeSheet: ActiveSheet? = nil
    @State private var pendingCompressSources: [URL] = []
    @State private var securityReport: ArchiveSecurityReport? = nil
    @State private var showOnboardingWizard: Bool = false
    @State private var testResult: ArchiveTestResult? = nil
    @State private var showProgressModal: Bool = false
    @State private var progressTitle: String = "İşlem Yapılıyor"
    @State private var activeProgress: ArchiveProgress = ArchiveProgress(fractionCompleted: 0, currentFilename: "", processedBytes: 0, totalBytes: 1)
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var successAlertMessage: String? = nil
    @State private var showSuccessAlert: Bool = false
    @State private var conflictingFileName: String = ""
    @State private var conflictResolutionAction: ((ConflictResolutionChoice, Bool) -> Void)? = nil
    @State private var resumeJournalRecord: SpaceSaverJournal.Record? = nil
    @State private var showResumeBanner: Bool = false

    public init() {
        let isDone = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") || AppSettings.shared.hasCompletedOnboarding
        self._showOnboardingWizard = State(initialValue: !isDone)
    }

    private var animationBinding: Animation? {
        settings.enableAnimations ? .spring(response: 0.35, dampingFraction: 0.8) : nil
    }

    public var body: some View {
        let mainContent = ZStack {
            VStack(spacing: 0) {
                // Üst Navigasyon ve Kontrol Çubuğu
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(settings.accentColorChoice.color)

                        Text("UnPack")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Spacer()

                    // Mod Seçici (Gezgin Modu vs. Hızlı Mod)
                    Picker("", selection: $currentMode) {
                        Label("Gezgin Modu", systemImage: "macwindow.on.rectangle").tag(AppMode.explorer)
                        Label("Hızlı Bırakma", systemImage: "bolt.shield.fill").tag(AppMode.quickDrop)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)

                    Spacer()

                    HStack(spacing: 6) {
                        // Gözat ve Sıkıştır Butonu
                        Button(action: browseAndCompress) {
                            Label("Sıkıştır", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Dosya veya klasör seçip sıkıştırın (Gözat)")

                        Button(action: openArchiveWithFilePicker) {
                            Label("Arşiv Aç", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Mevcut bir arşivi açın (⌘O)")

                        Button(action: { activeSheet = .diff(initialURL: openedArchiveURL) }) {
                            Image(systemName: "arrow.left.arrow.right")
                                .frame(width: 22, height: 18)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("İki arşivi karşılaştır (Diff)")

                        Button(action: { activeSheet = .settings }) {
                            Image(systemName: "gearshape")
                                .frame(width: 22, height: 18)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("UnPack Ayarları (⌘,)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Ana Mod İçeriği
                if currentMode == .explorer {
                    if let archiveURL = openedArchiveURL {
                        VStack(spacing: 0) {
                            if showResumeBanner, let journal = resumeJournalRecord {
                                HStack(spacing: 12) {
                                    Image(systemName: "bolt.badge.clock.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Yarıda Kalan Alan Açarak Çıkarma Tespit Edildi")
                                            .font(.system(size: 12, weight: .bold))
                                        Text("\(journal.completedItems.count) dosya önceden başarıyla çıkarıldı. Kaldığı yerden anında devam edebilirsiniz.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button("Kaldığı Yerden Devam Et") {
                                        showResumeBanner = false
                                        resumeSpaceSavingExtraction(for: archiveURL, journal: journal)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button("Yoksay") {
                                        showResumeBanner = false
                                        SpaceSaverJournal.shared.deleteJournalAndTail(for: archiveURL)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.12))
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color.orange.opacity(0.3)),
                                    alignment: .bottom
                                )
                            }

                            ArchiveBrowserView(
                                archiveURL: archiveURL,
                                items: archiveItems,
                                metadata: archiveMetadata,
                                currentPath: $currentPath,
                                searchText: $searchText,
                                selectedItemIDs: $selectedItemIDs,
                                onAddFiles: { triggerAddFiles() },
                                onExtract: { activeSheet = .extract },
                                onTestArchive: { runIntegrityTest() },
                                onPreviewItem: { item in previewItem(item) },
                                onDeleteSelected: { deleteSelectedItems() },
                                onCleanMacJunk: { cleanMacJunkFromCurrentArchive() },
                                onShowInfo: {
                                    if let meta = archiveMetadata {
                                        activeSheet = .info(metadata: meta)
                                    }
                                },
                                onConvertArchive: {
                                    if let src = openedArchiveURL {
                                        activeSheet = .convert(sourceURL: src)
                                    }
                                },
                                onDiffArchive: { activeSheet = .diff(initialURL: openedArchiveURL) },
                                onLockArchive: { promptPasswordProtection() },
                                onRepairArchive: { repairArchive() },
                                onNavigateTo: { path in currentPath = path },
                                onNavigateUp: { navigateUp() },
                                securityReport: securityReport,
                                onShowSecurity: {
                                    if let rep = securityReport {
                                        activeSheet = .security(report: rep)
                                    }
                                },
                                onNewArchive: { browseAndCompress() }
                            )
                        }
                    } else {
                        emptyExplorerWelcomeView
                    }
                } else {
                    DropZoneView(
                        isHovering: $isWindowDropTargeted,
                        onFilesDropped: { urls in handleDroppedFiles(urls) },
                        onBrowseFiles: { browseAndCompress() },
                        onSwitchToExplorer: { currentMode = .explorer }
                    )
                }
            }

            // Canlı İlerleme Modalı
            if showProgressModal {
                ZStack {
                    Color.black.opacity(0.35)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .ignoresSafeArea()

                    ProgressModalView(
                        title: progressTitle,
                        progress: activeProgress,
                        onCancel: {
                            Task { await ArchiveManager.shared.cancelCurrentOperation() }
                            showProgressModal = false
                        }
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }

            if showOnboardingWizard {
                ZStack {
                    Color.black.opacity(0.40)
                        .background(.ultraThinMaterial.opacity(0.75))
                        .ignoresSafeArea()

                    OnboardingWizardView(isPresented: $showOnboardingWizard)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 28)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
                .zIndex(100)
                .transition(.opacity)
            }
        }
        .frame(minWidth: 860, idealWidth: 960, minHeight: 620, idealHeight: 680)
        .preferredColorScheme(settings.selectedTheme.colorScheme)
        .tint(settings.accentColorChoice.color)
        .accentColor(settings.accentColorChoice.color)
        .animation(animationBinding, value: showProgressModal)
        .onDrop(of: [.fileURL], isTargeted: $isWindowDropTargeted) { providers in
            loadDroppedFiles(providers: providers)
            return true
        }
        .onAppear(perform: handleOnAppear)
        .alert("UnPack Bildirimi", isPresented: $showErrorAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Bir hata meydana geldi.")
        }
        .alert("İşlem Başarılı", isPresented: $showSuccessAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(successAlertMessage ?? "İşlem başarıyla tamamlandı.")
        }

        let contentWithSheet = mainContent
            .sheet(item: $activeSheet) { sheet in
                renderActiveSheet(sheet)
            }

        let v1 = applyFileNotificationListeners(to: contentWithSheet)
        let v2 = applyExtractionNotificationListeners(to: AnyView(v1))
        let v3 = applyArchiveManipulationListeners(to: AnyView(v2))
        return AnyView(v3)
    }

    private func handleOnAppear() {
        let isDone = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") || settings.hasCompletedOnboarding
        if !isDone {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showOnboardingWizard = true
            }
        }
    }

    private func applyFileNotificationListeners<V: View>(to content: V) -> some View {
        content
            .onOpenURL { url in
                loadArchive(from: url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARFileDropped)) { notif in
                if let fileURL = notif.object as? URL {
                    loadArchive(from: fileURL)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARNewArchive)) { _ in
                browseAndCompress()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARCompressFilesWithDialog)) { notif in
                if let urls = notif.object as? [URL], !urls.isEmpty {
                    pendingCompressSources = urls
                    activeSheet = .compress(sources: urls)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRAROpenArchive)) { _ in
                openArchiveWithFilePicker()
            }
    }

    private func applyExtractionNotificationListeners<V: View>(to content: V) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .macRARExtract)) { _ in
                if openedArchiveURL != nil { activeSheet = .extract }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARExtractHere)) { _ in
                if let arcURL = openedArchiveURL {
                    startExtraction(baseDestinationURL: arcURL.deletingLastPathComponent(), selectedOnly: false, overwrite: false, revealInFinder: true, trashOriginal: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARExtractToFolder)) { _ in
                if let arcURL = openedArchiveURL {
                    let folderName = arcURL.deletingPathExtension().lastPathComponent
                    let dest = arcURL.deletingLastPathComponent().appendingPathComponent(folderName, isDirectory: true)
                    startExtraction(baseDestinationURL: dest, selectedOnly: false, overwrite: false, revealInFinder: true, trashOriginal: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARExtractToChosen)) { _ in
                if openedArchiveURL != nil { activeSheet = .extract }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARExtractSelected)) { _ in
                if openedArchiveURL != nil, !selectedItemIDs.isEmpty {
                    startExtraction(baseDestinationURL: openedArchiveURL!.deletingLastPathComponent(), selectedOnly: true, overwrite: false, revealInFinder: true, trashOriginal: false)
                }
            }
    }

    private func applyArchiveManipulationListeners<V: View>(to content: V) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .macRARAddFiles)) { _ in
                triggerAddFiles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARDeleteSelected)) { _ in
                deleteSelectedItems()
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARRefresh)) { _ in
                if let arcURL = openedArchiveURL { loadArchive(from: arcURL) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARShowInFinder)) { _ in
                if let arcURL = openedArchiveURL { NSWorkspace.shared.activateFileViewerSelecting([arcURL]) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARTest)) { _ in
                if openedArchiveURL != nil { runIntegrityTest() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARInfo)) { _ in
                if let meta = archiveMetadata { activeSheet = .info(metadata: meta) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARRepair)) { _ in
                repairArchive()
            }
            .onReceive(NotificationCenter.default.publisher(for: .cofferSecurity)) { _ in
                if let rep = securityReport { activeSheet = .security(report: rep) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .macRARShowOnboarding)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showOnboardingWizard = true
                }
            }
    }

    @ViewBuilder
    private func renderActiveSheet(_ sheet: ActiveSheet) -> some View {
        let isPresentedBinding = Binding<Bool>(
            get: { activeSheet != nil },
            set: { if !$0 { activeSheet = nil } }
        )

        switch sheet {
        case .compress(let sources):
            CompressDialog(
                sourceURLs: sources,
                isPresented: isPresentedBinding,
                onStartCompress: { format, level, password, encHeaders, isSolid, splitMB, rr, sfx, delSources, stripMac, targetURL, finalFiles in
                    self.pendingCompressSources = finalFiles
                    self.startCompression(
                        format: format,
                        level: level,
                        password: password,
                        encryptHeaders: encHeaders,
                        isSolid: isSolid,
                        splitVolumeSizeMB: splitMB,
                        recoveryRecord: rr,
                        isSFX: sfx,
                        deleteSources: delSources,
                        stripMacJunk: stripMac,
                        targetURL: targetURL
                    )
                }
            )

        case .conflict(let fileName):
            ExtractionConflictDialog(
                conflictingFileName: fileName,
                incomingFileSize: 0,
                onResolve: { choice, applyToAll in
                    activeSheet = nil
                    conflictResolutionAction?(choice, applyToAll)
                }
            )

        case .extract:
            ExtractDialog(
                archiveURL: openedArchiveURL,
                archiveName: openedArchiveURL?.lastPathComponent ?? "Arşiv",
                items: archiveItems,
                selectedItemsCount: selectedItemIDs.count,
                isPresented: isPresentedBinding,
                onStartExtract: { destURL, selectedOnly, overwrite, reveal, trashOriginal, useSpaceSaver in
                    activeSheet = nil
                    startExtraction(
                        baseDestinationURL: destURL,
                        selectedOnly: selectedOnly,
                        overwrite: overwrite,
                        revealInFinder: reveal,
                        trashOriginal: trashOriginal,
                        useSpaceSaver: useSpaceSaver
                    )
                }
            )

        case .password(let name):
            PasswordPromptDialog(
                archiveName: name,
                isPresented: isPresentedBinding,
                onConfirmPassword: { password, saveKeychain in
                    activeSheet = nil
                    unlockArchive(with: password, saveKeychain: saveKeychain)
                }
            )

        case .info(let meta):
            ArchiveInfoDialog(metadata: meta, isPresented: isPresentedBinding)

        case .testResult(let res):
            TestResultDialog(result: res, isPresented: isPresentedBinding)

        case .diff(let initialURL):
            ArchiveDiffView(isPresented: isPresentedBinding, initialArchiveURL: initialURL)

        case .convert(let src):
            ArchiveConverterView(
                sourceURL: src,
                isPresented: isPresentedBinding,
                onStartConversion: { targetFormat, level, targetURL in
                    activeSheet = nil
                    startConversion(targetFormat: targetFormat, level: level, targetURL: targetURL)
                }
            )

        case .settings:
            SettingsView(isPresented: isPresentedBinding)

        case .repair(let arcURL):
            ArchiveRepairDialog(
                archiveURL: arcURL,
                isPresented: isPresentedBinding,
                onRepairCompleted: { repairedURL in
                    activeSheet = nil
                    self.loadArchive(from: repairedURL)
                }
            )

        case .security(let rep):
            ArchiveSecurityView(
                report: rep,
                isPresented: isPresentedBinding,
                onSafeExtract: {
                    activeSheet = nil
                    startSafeExtraction()
                },
                onRegularExtract: {
                    activeSheet = .extract
                }
            )
        }
    }

    // MARK: - Karşılama Ekranı

    private var emptyExplorerWelcomeView: some View {
        VStack(spacing: 20) {
            Spacer()

            // 1. Apple macOS Standart İkon Kutusu
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(settings.accentColorChoice.color.opacity(0.12))
                    .frame(width: 84, height: 84)

                Image(systemName: "archivebox")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(settings.accentColorChoice.color)
            }

            // 2. Başlık ve Açıklama (SF Pro Typography)
            VStack(spacing: 6) {
                Text("UnPack Arşiv Gezgini")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Açmak istediğiniz bir arşivi buraya sürükleyin veya dosyalara göz atın.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 3. Apple macOS Eylem Düğmeleri
            HStack(spacing: 12) {
                Button(action: browseAndCompress) {
                    Label("Dosya Seç ve Sıkıştır...", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button(action: openArchiveWithFilePicker) {
                    Label("Bir Arşiv Aç...", systemImage: "folder.fill")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: { currentMode = .quickDrop }) {
                    Label("Hızlı Bırakma", systemImage: "bolt.shield.fill")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            // 4. Desteklenen Formatlar Rozet Şeridi
            HStack(spacing: 6) {
                LiquidGlassFormatBadge(format: .zip, size: .small)
                LiquidGlassFormatBadge(format: .rar, size: .small)
                LiquidGlassFormatBadge(format: .sevenZip, size: .small)
                LiquidGlassFormatBadge(format: .tarGz, size: .small)
                LiquidGlassFormatBadge(format: .iso, size: .small)
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Arşiv Yükleme & İşlem Fonksiyonları

    private func browseAndCompress() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Sıkıştır"
        panel.message = "Sıkıştırmak istediğiniz dosya veya klasörleri seçin:"

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            pendingCompressSources = panel.urls
            activeSheet = .compress(sources: panel.urls)
        }
    }

    private func openArchiveWithFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Aç"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "rar") ?? .data,
            .zip,
            UTType(filenameExtension: "7z") ?? .data,
            UTType(filenameExtension: "tar") ?? .data,
            UTType(filenameExtension: "gz") ?? .data,
            UTType(filenameExtension: "bz2") ?? .data,
            UTType(filenameExtension: "xz") ?? .data
        ]

        if panel.runModal() == .OK, let url = panel.url {
            loadArchive(from: url)
        }
    }

    private func loadArchive(from url: URL, password: String? = nil) {
        Task {
            do {
                await MainActor.run {
                    self.progressTitle = "Arşiv Taranıyor..."
                    self.showProgressModal = true
                    self.activeProgress = ArchiveProgress(fractionCompleted: 0.1, currentFilename: url.lastPathComponent, processedBytes: 0, totalBytes: 1)
                }

                let (items, metadata) = try await ArchiveManager.shared.openArchive(at: url, password: password)
                let report = ArchiveSecurityEngine.shared.analyze(archiveURL: url, items: items)

                await MainActor.run {
                    self.openedArchiveURL = url
                    self.archiveItems = items
                    self.archiveMetadata = metadata
                    self.securityReport = report
                    self.currentPath = ""
                    self.selectedItemIDs.removeAll()
                    self.currentMode = .explorer
                    self.showProgressModal = false

                    if metadata.isEncrypted && password == nil {
                        self.activeSheet = .password(archiveName: url.lastPathComponent)
                    }

                    if SpaceSaverJournal.shared.hasActiveJournal(for: url),
                       let journal = SpaceSaverJournal.shared.readJournal(for: url) {
                        self.resumeJournalRecord = journal
                        self.showResumeBanner = true
                    } else {
                        self.resumeJournalRecord = nil
                        self.showResumeBanner = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.showProgressModal = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func handleDroppedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        if urls.count == 1, let firstURL = urls.first, let _ = ArchiveFormat.detect(from: firstURL) {
            loadArchive(from: firstURL)
        } else {
            pendingCompressSources = urls
            activeSheet = .compress(sources: urls)
        }
    }

    private func startCompression(
        format: ArchiveFormat,
        level: CompressionLevel,
        password: String?,
        encryptHeaders: Bool = false,
        isSolid: Bool = true,
        splitVolumeSizeMB: Int? = nil,
        recoveryRecord: Bool = true,
        isSFX: Bool = false,
        deleteSources: Bool = false,
        stripMacJunk: Bool = true,
        targetURL: URL
    ) {
        activeSheet = nil
        progressTitle = "Arşiv Oluşturuluyor..."
        activeProgress = ArchiveProgress(fractionCompleted: 0.1, currentFilename: targetURL.lastPathComponent, processedBytes: 0, totalBytes: 1)
        showProgressModal = true

        Task {
            do {
                let stream = await ArchiveManager.shared.compress(
                    sourceURLs: pendingCompressSources,
                    destinationURL: targetURL,
                    format: format,
                    level: level,
                    password: password,
                    encryptHeaders: encryptHeaders,
                    isSolid: isSolid,
                    splitVolumeSizeMB: splitVolumeSizeMB,
                    recoveryRecordPercentage: recoveryRecord ? 3 : nil,
                    isSFX: isSFX,
                    deleteSources: deleteSources,
                    stripMacJunk: stripMacJunk
                )

                for try await prog in stream {
                    await MainActor.run {
                        self.activeProgress = prog
                    }
                }

                await MainActor.run {
                    self.showProgressModal = false
                    if settings.playSoundOnCompletion { NSSound.beep() }
                    self.loadArchive(from: targetURL)
                }
            } catch {
                await MainActor.run {
                    self.showProgressModal = false
                    self.errorMessage = "Sıkıştırma işlemi başarısız: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func startSafeExtraction() {
        guard let arcURL = openedArchiveURL else { return }
        let defaultDest = arcURL.deletingLastPathComponent().appendingPathComponent("\(arcURL.deletingPathExtension().lastPathComponent)_Guvenli")

        // Güvenli ayıklama: Tehlikeli yürütülebilir ve dizin aşımı dosyalarını filtreler
        let dangerousExtensions: Set<String> = ["exe", "msi", "bat", "cmd", "scr", "vbs", "ps1", "app", "command"]
        let safeItems = archiveItems.filter { item in
            if item.path.contains("../") || item.path.contains("..\\") || item.path.hasPrefix("/") {
                return false
            }
            let ext = (item.name.lowercased() as NSString).pathExtension
            if dangerousExtensions.contains(ext) {
                return false
            }
            return true
        }

        performActualExtraction(
            arcURL: arcURL,
            finalDestinationURL: defaultDest,
            selectedItems: safeItems,
            revealInFinder: true,
            trashOriginal: false
        )
    }

    private func startExtraction(
        baseDestinationURL: URL,
        selectedOnly: Bool,
        overwrite: Bool,
        revealInFinder: Bool,
        trashOriginal: Bool,
        useSpaceSaver: Bool = false
    ) {
        guard let arcURL = openedArchiveURL else { return }

        // Kritik Güvenlik Tehdidi Koruması (Zip Bomb / Zip Slip)
        if let rep = securityReport, rep.hasCriticalRisk, !overwrite {
            self.activeSheet = .security(report: rep)
            return
        }

        let (finalDestinationURL, _) = SmartExtractor.shared.resolveDestinationPath(
            archiveURL: arcURL,
            items: archiveItems,
            baseDestinationURL: baseDestinationURL,
            enableSmartExtraction: settings.enableSmartExtraction
        )

        let selectedItems = selectedOnly ? archiveItems.filter { selectedItemIDs.contains($0.id) } : nil
        let itemsToCheck = selectedItems ?? archiveItems

        // Hedefte aynı isimde dosya var mı kontrolü
        let destinationItems = (try? FileManager.default.contentsOfDirectory(atPath: finalDestinationURL.path)) ?? []
        let conflicting = itemsToCheck.first { destinationItems.contains($0.name) }

        if let conf = conflicting, !overwrite {
            self.conflictingFileName = conf.name
            self.conflictResolutionAction = { choice, applyToAll in
                switch choice {
                case .overwrite:
                    self.performActualExtraction(
                        arcURL: arcURL,
                        finalDestinationURL: finalDestinationURL,
                        selectedItems: selectedItems,
                        revealInFinder: revealInFinder,
                        trashOriginal: trashOriginal,
                        useSpaceSaver: useSpaceSaver
                    )
                case .autoRename:
                    let renamedURL = finalDestinationURL.appendingPathComponent("Cikarilan_\(UUID().uuidString.prefix(4))")
                    try? FileManager.default.createDirectory(at: renamedURL, withIntermediateDirectories: true)
                    self.performActualExtraction(
                        arcURL: arcURL,
                        finalDestinationURL: renamedURL,
                        selectedItems: selectedItems,
                        revealInFinder: revealInFinder,
                        trashOriginal: trashOriginal,
                        useSpaceSaver: useSpaceSaver
                    )
                case .skip, .cancel:
                    break
                }
            }
            self.activeSheet = .conflict(fileName: conf.name)
            return
        }

        performActualExtraction(
            arcURL: arcURL,
            finalDestinationURL: finalDestinationURL,
            selectedItems: selectedItems,
            revealInFinder: revealInFinder,
            trashOriginal: trashOriginal,
            useSpaceSaver: useSpaceSaver
        )
    }

    private func performActualExtraction(
        arcURL: URL,
        finalDestinationURL: URL,
        selectedItems: [ArchiveItem]?,
        revealInFinder: Bool,
        trashOriginal: Bool,
        useSpaceSaver: Bool = false,
        isResume: Bool = false
    ) {
        progressTitle = useSpaceSaver ? "Alan Açarak Çıkartılıyor (Space-Saver)..." : "Dosyalar Çıkartılıyor..."
        showProgressModal = true

        Task {
            do {
                let stream: AsyncThrowingStream<ArchiveProgress, Error>
                if useSpaceSaver {
                    stream = await ArchiveManager.shared.extractWithSpaceSaving(
                        archiveURL: arcURL,
                        destinationURL: finalDestinationURL,
                        items: archiveItems,
                        selectedItems: selectedItems,
                        password: nil,
                        isResume: isResume
                    )
                } else {
                    stream = await ArchiveManager.shared.extract(
                        archiveURL: arcURL,
                        destinationURL: finalDestinationURL,
                        selectedItems: selectedItems,
                        password: nil
                    )
                }

                for try await prog in stream {
                    await MainActor.run {
                        self.activeProgress = prog
                    }
                }

                await MainActor.run {
                    self.showProgressModal = false
                    if !useSpaceSaver {
                        SmartExtractor.shared.performPostExtractionActions(
                            archiveURL: arcURL,
                            destinationURL: finalDestinationURL,
                            trashOriginal: trashOriginal,
                            revealInFinder: revealInFinder,
                            playSound: settings.playSoundOnCompletion
                        )
                    } else {
                        if settings.playSoundOnCompletion {
                            NSSound.beep()
                        }
                        if revealInFinder {
                            NSWorkspace.shared.selectFile(finalDestinationURL.path, inFileViewerRootedAtPath: "")
                        }
                        self.successAlertMessage = "Alan açılarak çıkarma başarıyla tamamlandı. Arşiv disk alanı sisteme geri kazandırıldı."
                        self.showSuccessAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.showProgressModal = false
                    self.errorMessage = "Çıkarma işlemi başarısız: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func resumeSpaceSavingExtraction(for arcURL: URL, journal: SpaceSaverJournal.Record) {
        let destURL = URL(fileURLWithPath: journal.destinationPath)
        performActualExtraction(
            arcURL: arcURL,
            finalDestinationURL: destURL,
            selectedItems: nil,
            revealInFinder: settings.revealInFinderAfterExtract,
            trashOriginal: false,
            useSpaceSaver: true,
            isResume: true
        )
    }

    private func startConversion(targetFormat: ArchiveFormat, level: CompressionLevel, targetURL: URL) {
        guard let arcURL = openedArchiveURL else { return }

        progressTitle = "Arşiv Dönüştürülüyor (\(targetFormat.rawValue))..."
        showProgressModal = true

        Task {
            do {
                let stream = ArchiveConverter.shared.convert(
                    sourceURL: arcURL,
                    targetFormat: targetFormat,
                    targetLevel: level,
                    targetURL: targetURL
                )

                for try await prog in stream {
                    await MainActor.run {
                        self.activeProgress = prog
                    }
                }

                await MainActor.run {
                    self.showProgressModal = false
                    if settings.playSoundOnCompletion { NSSound.beep() }
                    self.loadArchive(from: targetURL)
                }
            } catch {
                await MainActor.run {
                    self.showProgressModal = false
                    self.errorMessage = "Dönüştürme hatası: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func cleanMacJunkFromCurrentArchive() {
        guard let arcURL = openedArchiveURL else { return }

        progressTitle = "macOS Artıkları Temizleniyor..."
        showProgressModal = true

        Task {
            do {
                let cleanedCount = try await AppleJunkSanitizer.shared.cleanArchiveFromMacJunk(archiveURL: arcURL)
                await MainActor.run {
                    self.showProgressModal = false
                    if cleanedCount > 0 {
                        self.successAlertMessage = "Arşiv başarıyla temizlendi!\nToplam \(cleanedCount) adet gereksiz Mac kalıntısı (.DS_Store, __MACOSX, ._*) arşivden kaldırıldı."
                        self.showSuccessAlert = true
                        self.loadArchive(from: arcURL)
                    } else {
                        self.successAlertMessage = "Arşivde herhangi bir gereksiz Mac kalıntısı (.DS_Store vb.) bulunamadı. Arşiviniz zaten tertemiz!"
                        self.showSuccessAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.showProgressModal = false
                    self.errorMessage = "Temizleme hatası: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func runIntegrityTest() {
        guard let url = openedArchiveURL else { return }

        progressTitle = "Arşiv Bütünlüğü Test Ediliyor..."
        activeProgress = ArchiveProgress(fractionCompleted: 0.2, currentFilename: url.lastPathComponent, processedBytes: 0, totalBytes: 1)
        showProgressModal = true

        Task {
            do {
                let res = try await ArchiveManager.shared.testIntegrity(of: url)
                await MainActor.run {
                    self.showProgressModal = false
                    self.testResult = res
                    self.activeSheet = .testResult(result: res)
                }
            } catch {
                await MainActor.run {
                    self.showProgressModal = false
                    let res = ArchiveTestResult(isSuccess: false, totalItemsChecked: 0, errors: [error.localizedDescription])
                    self.testResult = res
                    self.activeSheet = .testResult(result: res)
                }
            }
        }
    }

    private func previewItem(_ item: ArchiveItem) {
        guard let arcURL = openedArchiveURL else { return }

        Task {
            do {
                let tempURL = try await ArchiveManager.shared.extractItemForPreview(archiveURL: arcURL, item: item)
                await MainActor.run {
                    QuickLookHelper.shared.previewFile(at: tempURL)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Önizleme dosyası açılamadı: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func triggerAddFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Arşive Ekle"

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            if let arcURL = openedArchiveURL {
                progressTitle = "Dosyalar Arşive Ekleniyor..."
                activeProgress = ArchiveProgress(fractionCompleted: 0.2, currentFilename: panel.urls.first?.lastPathComponent ?? "", processedBytes: 0, totalBytes: 1)
                showProgressModal = true

                Task {
                    do {
                        try await ArchiveManager.shared.addFiles(to: arcURL, files: panel.urls)
                        await MainActor.run {
                            self.showProgressModal = false
                            self.loadArchive(from: arcURL)
                        }
                    } catch {
                        await MainActor.run {
                            self.showProgressModal = false
                            self.errorMessage = "Dosya ekleme hatası: \(error.localizedDescription)"
                            self.showErrorAlert = true
                        }
                    }
                }
            } else {
                pendingCompressSources = panel.urls
                activeSheet = .compress(sources: panel.urls)
            }
        }
    }

    private func deleteSelectedItems() {
        guard let arcURL = openedArchiveURL else { return }
        guard !selectedItemIDs.isEmpty else {
            errorMessage = "Lütfen silmek istediğiniz dosya veya klasörleri seçin."
            showErrorAlert = true
            return
        }

        let itemsToDelete = archiveItems.filter { selectedItemIDs.contains($0.id) }
        progressTitle = "Dosyalar Arşivden Siliniyor..."
        activeProgress = ArchiveProgress(fractionCompleted: 0.2, currentFilename: itemsToDelete.first?.name ?? "", processedBytes: 0, totalBytes: 1)
        showProgressModal = true

        Task {
            do {
                try await ArchiveManager.shared.deleteItems(from: arcURL, items: itemsToDelete)
                await MainActor.run {
                    self.showProgressModal = false
                    self.loadArchive(from: arcURL)
                }
            } catch {
                await MainActor.run {
                    self.showProgressModal = false
                    self.errorMessage = "Silme işlemi tamamlanamadı: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func promptPasswordProtection() {
        guard let arcURL = openedArchiveURL else { return }

        let alert = NSAlert()
        alert.messageText = "Arşivi Parola ile Kilitle"
        alert.informativeText = "'\(arcURL.lastPathComponent)' arşivi AES-256 ile şifrelenecek. Lütfen bir parola belirleyin:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Kilitle")
        alert.addButton(withTitle: "İptal")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let password = input.stringValue
            guard !password.isEmpty else { return }

            progressTitle = "Arşiv Şifreleniyor..."
            showProgressModal = true

            Task {
                do {
                    let lockedURL = try await ArchiveManager.shared.lockArchiveWithPassword(archiveURL: arcURL, password: password)
                    await MainActor.run {
                        self.showProgressModal = false
                        self.loadArchive(from: lockedURL)
                    }
                } catch {
                    await MainActor.run {
                        self.showProgressModal = false
                        self.errorMessage = "Şifreleme hatası: \(error.localizedDescription)"
                        self.showErrorAlert = true
                    }
                }
            }
        }
    }

    private func repairArchive() {
        guard let arcURL = openedArchiveURL else {
            openArchiveWithFilePicker()
            return
        }
        activeSheet = .repair(archiveURL: arcURL)
    }

    private func unlockArchive(with pass: String, saveKeychain: Bool) {
        guard let url = openedArchiveURL else { return }
        if saveKeychain {
            KeychainManager.shared.savePassword(pass, for: url.lastPathComponent)
        }
        loadArchive(from: url, password: pass)
    }

    private func navigateUp() {
        if !currentPath.isEmpty {
            let parts = currentPath.split(separator: "/")
            if parts.count > 1 {
                currentPath = parts.dropLast().joined(separator: "/")
            } else {
                currentPath = ""
            }
        }
    }

    private func loadDroppedFiles(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                self.handleDroppedFiles(urls)
            }
        }
    }
}



