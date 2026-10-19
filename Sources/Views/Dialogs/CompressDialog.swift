import SwiftUI
import UniformTypeIdentifiers

/// Sade, elit ve modern macOS tasarım standartlarında Yeni Arşiv Oluşturma Penceresi
public struct CompressDialog: View {
    @ObservedObject private var settings = AppSettings.shared
    public let initialSourceURLs: [URL]
    @Binding public var isPresented: Bool

    public let onStartCompressWithOptions: (
        _ format: ArchiveFormat,
        _ level: CompressionLevel,
        _ password: String?,
        _ encryptHeaders: Bool,
        _ isSolid: Bool,
        _ splitVolumeSizeMB: Int?,
        _ recoveryRecord: Bool,
        _ isSFX: Bool,
        _ deleteSources: Bool,
        _ stripMacJunk: Bool,
        _ targetURL: URL,
        _ sourceURLs: [URL]
    ) -> Void

    @State private var currentSourceURLs: [URL]
    @State private var sourceStats: CompressionSimulator.SourceStats
    @State private var selectedFormat: ArchiveFormat = .rar
    @State private var selectedLevel: CompressionLevel = .normal
    @State private var password: String = ""
    @State private var isPasswordProtected: Bool = false
    @State private var encryptHeaders: Bool = false
    @State private var isSolid: Bool = true
    @State private var hasRecoveryRecord: Bool = true
    @State private var isSFX: Bool = false
    @State private var deleteSources: Bool = false
    @State private var stripMacJunk: Bool = true
    @State private var archiveFileName: String = ""
    @State private var destinationDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    @State private var isDropTargeted: Bool = false
    @State private var isSplitArchive: Bool = false
    @State private var splitVolumeSizeMB: Int = 25

    public init(
        sourceURLs: [URL],
        isPresented: Binding<Bool>,
        onStartCompress: @escaping (
            ArchiveFormat,
            CompressionLevel,
            String?,
            Bool,
            Bool,
            Int?,
            Bool,
            Bool,
            Bool,
            Bool,
            URL,
            [URL]
        ) -> Void
    ) {
        self.initialSourceURLs = sourceURLs
        self._isPresented = isPresented
        self.onStartCompressWithOptions = onStartCompress
        self._currentSourceURLs = State(initialValue: sourceURLs)
        self._sourceStats = State(initialValue: CompressionSimulator.shared.analyzeSources(urls: sourceURLs))

        let defaultFmt: ArchiveFormat
        if AppSettings.shared.defaultFormat.uppercased() == "ZIP" {
            defaultFmt = .zip
        } else if AppSettings.shared.defaultFormat.uppercased() == "7Z" {
            defaultFmt = .sevenZip
        } else {
            defaultFmt = .rar
        }
        self._selectedFormat = State(initialValue: defaultFmt)
        self._selectedLevel = State(initialValue: AppSettings.shared.defaultCompressionLevelEnum)

        let initialName = sourceURLs.first?.deletingPathExtension().lastPathComponent ?? "Yeni_Arşiv"
        self._archiveFileName = State(initialValue: initialName)
    }

    /// 6 parametreli geriye dönük uyumlu başlatıcı
    public init(
        sourceURLs: [URL],
        isPresented: Binding<Bool>,
        onStartCompress: @escaping (ArchiveFormat, CompressionLevel, String?, Bool, URL, [URL]) -> Void
    ) {
        self.init(sourceURLs: sourceURLs, isPresented: isPresented) { format, level, pass, encHeaders, solid, splitMB, rr, sfx, del, strip, target, sources in
            onStartCompress(format, level, pass, strip, target, sources)
        }
    }

    private var targetFileURL: URL {
        let cleanName = archiveFileName.isEmpty ? "Arşiv" : archiveFileName
        if isSplitArchive {
            if selectedFormat == .sevenZip {
                return destinationDirectory.appendingPathComponent("\(cleanName).7z.001")
            } else {
                return destinationDirectory.appendingPathComponent("\(cleanName).part1.\(selectedFormat.primaryExtension)")
            }
        }
        return destinationDirectory.appendingPathComponent("\(cleanName).\(selectedFormat.primaryExtension)")
    }

    private var simulation: CompressionSimulator.SimulationResult {
        CompressionSimulator.shared.simulate(stats: sourceStats, format: selectedFormat, level: selectedLevel)
    }

    private var sourceSummaryText: String {
        if currentSourceURLs.isEmpty {
            return "1.0 GB referans model üzerinden hesaplanıyor"
        } else if currentSourceURLs.count == 1 {
            return "\(currentSourceURLs[0].lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: simulation.originalTotalSize, countStyle: .file)))"
        } else {
            return "\(currentSourceURLs.count) öğe (\(ByteCountFormatter.string(fromByteCount: simulation.originalTotalSize, countStyle: .file)))"
        }
    }

    // Seçilen formata göre desteklenen özellikler
    private var supportsEncryption: Bool {
        selectedFormat == .rar || selectedFormat == .sevenZip || selectedFormat == .zip
    }

    private var supportsHeaderEncryption: Bool {
        selectedFormat == .rar || selectedFormat == .sevenZip
    }

    private var supportsSolid: Bool {
        selectedFormat == .rar || selectedFormat == .sevenZip
    }

    private var supportsRecoveryRecord: Bool {
        selectedFormat == .rar
    }

    private var supportsSFX: Bool {
        selectedFormat == .rar || selectedFormat == .sevenZip
    }

    private var isRarMissing: Bool {
        selectedFormat == .rar && UnrarEngine.availableRarPath == nil
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. BAŞLIK
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(settings.accentColorChoice.color.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(settings.accentColorChoice.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Yeni Arşiv Oluştur")
                        .font(.system(size: 15, weight: .semibold))

                    Text(sourceSummaryText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: chooseSourceFiles) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Dosya Ekle")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // RAR Aracı Eksik Uyarısı
            if isRarMissing {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(settings.accentColorChoice.color)
                    Text("RAR 5 formatında arşiv oluşturmak için RARLAB 'RAR for macOS' aracı gereklidir.")
                        .font(.system(size: 11))
                    Spacer()
                    Button("RAR Aracını İndir") {
                        if let url = URL(string: "https://www.rarlab.com/download.htm") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(settings.accentColorChoice.color.opacity(0.12))
                Divider()
            }

            // 2. ANA İÇERİK
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Canlı Referans ve Tahmin Kartı
                    if settings.enableSizeSimulator {
                        liveEstimateCard
                            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                                handleDroppedFiles(providers: providers)
                                return true
                            }
                    }

                    // Biçim ve Seviye Kartı
                    formatAndLevelCard

                    // Dosya Adı ve Hedef Dizin
                    fileAndDestinationCard

                    // Güvenlik ve Gelişmiş Seçenekler
                    optionsCard
                }
                .padding(18)
            }

            Divider()

            // 3. ALT AKSİYON BARI
            HStack(spacing: 12) {
                Button("İptal") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Arşiv Oluştur") {
                    isPresented = false
                    let pass = isPasswordProtected && !password.isEmpty ? password : nil
                    let splitMB = isSplitArchive ? splitVolumeSizeMB : nil
                    onStartCompressWithOptions(
                        selectedFormat,
                        selectedLevel,
                        pass,
                        encryptHeaders && supportsHeaderEncryption,
                        isSolid && supportsSolid,
                        splitMB,
                        hasRecoveryRecord && supportsRecoveryRecord,
                        isSFX && supportsSFX,
                        deleteSources,
                        stripMacJunk,
                        targetFileURL,
                        currentSourceURLs
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(currentSourceURLs.isEmpty && !sourceStats.isSampleReference)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 520, height: 600)
        .tint(settings.accentColorChoice.color)
    }

    // MARK: - Kart Bileşenleri

    private var liveEstimateCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Orijinal Boyut")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: simulation.originalTotalSize, countStyle: .file))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tahmini Boyut")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: simulation.estimatedCompressedSize, countStyle: .file))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(settings.accentColorChoice.color)
                }

                Spacer()

                if simulation.savingsPercentage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                        Text("%\(String(format: "%.0f", simulation.savingsPercentage)) Tasarruf")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
                }
            }

            GeometryReader { geo in
                let ratio = simulation.originalTotalSize > 0
                    ? max(0.04, min(1.0, Double(simulation.estimatedCompressedSize) / Double(simulation.originalTotalSize)))
                    : 0.5

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)

                    Capsule()
                        .fill(settings.accentColorChoice.color)
                        .frame(width: max(8, geo.size.width * CGFloat(ratio)), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text(simulation.formatBadge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))

                Text(simulation.speedLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                if simulation.isSampleReference {
                    Text("Örnek Referans")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private var formatAndLevelCard: some View {
        VStack(spacing: 14) {
            // Biçim Seçici (Apple Liquid Glass Format Seçici - 2 Sıralı Simetrik Izgara)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Biçim")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(selectedFormat.localizedDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                LiquidGlassFormatPicker(selection: $selectedFormat)
            }

            Divider()
                .opacity(0.4)

            // Sıkıştırma Seviyesi (Tam Genişlikte, Simetrik Apple Menüsü)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Düzey")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(selectedLevel.localizedDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Menu {
                    ForEach(CompressionLevel.allCases) { lvl in
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedLevel = lvl
                            }
                        }) {
                            HStack {
                                Text(lvl.title)
                                if selectedLevel == lvl {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: levelIcon(for: selectedLevel))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(settings.accentColorChoice.color)

                        Text(selectedLevel.title)
                            .font(.system(size: 12, weight: .medium))

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private func levelIcon(for level: CompressionLevel) -> String {
        switch level {
        case .store: return "bolt.horizontal.fill"
        case .fastest: return "hare.fill"
        case .fast: return "bolt.fill"
        case .normal: return "gauge.medium"
        case .good: return "leaf.fill"
        case .best: return "crown.fill"
        }
    }

    private var fileAndDestinationCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Arşiv Adı")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 80, alignment: .leading)

                TextField("Arşiv adı", text: $archiveFileName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                LiquidGlassFormatBadge(format: selectedFormat, size: .small)
            }

            HStack(spacing: 10) {
                Text("Hedef")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 80, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))

                    Text(destinationDirectory.lastPathComponent)
                        .font(.system(size: 12))
                        .lineLimit(1)

                    Spacer()

                    Button("Değiştir...") {
                        chooseDestination()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(settings.accentColorChoice.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private var optionsCard: some View {
        VStack(spacing: 10) {
            // Parola Koruması (AES-256)
            Toggle(isOn: $isPasswordProtected.animation(.spring(response: 0.28, dampingFraction: 0.8))) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11))
                        .foregroundColor(supportsEncryption ? settings.accentColorChoice.color : .secondary)
                    Text("Parola Koruması (AES-256 Şifreleme)")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .disabled(!supportsEncryption)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isPasswordProtected && supportsEncryption {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Text("Parola")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 80, alignment: .leading)

                        SecureField("Parola belirleyin", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    // Dosya Adlarını Şifrele (-hp / -mhe)
                    Toggle(isOn: $encryptHeaders) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.badge.lock")
                                .font(.system(size: 11))
                            Text("Dosya İsimlerini de Şifrele (-hp / -mhe)")
                                .font(.system(size: 11))
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(!supportsHeaderEncryption)
                    .padding(.leading, 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 2)
            }

            // Katı Arşiv (Solid)
            Toggle(isOn: $isSolid) {
                HStack(spacing: 6) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 11))
                        .foregroundColor(supportsSolid ? .purple : .secondary)
                    Text("Katı Arşiv Oluştur (Solid - Daha Yüksek Sıkıştırma)")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .disabled(!supportsSolid)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Kurtarma Kaydı (Recovery Record - RAR)
            Toggle(isOn: $hasRecoveryRecord) {
                HStack(spacing: 6) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 11))
                        .foregroundColor(supportsRecoveryRecord ? .green : .secondary)
                    Text("Kurtarma Kaydı Ekle (%3 Recovery Record - RAR)")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .disabled(!supportsRecoveryRecord)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Çok Parçalı Arşiv (Split / Multi-volume)
            Toggle(isOn: $isSplitArchive.animation(.spring(response: 0.28, dampingFraction: 0.8))) {
                HStack(spacing: 6) {
                    Image(systemName: "square.split.2x1")
                        .font(.system(size: 11))
                        .foregroundColor(.indigo)
                    Text("Arşivi Ciltlere Böl (Split Volumes)")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSplitArchive {
                HStack(spacing: 10) {
                    Text("Cilt Boyutu")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 80, alignment: .leading)

                    Picker("", selection: $splitVolumeSizeMB) {
                        Text("10 MB (Web / Mesajlaşma)").tag(10)
                        Text("25 MB (E-posta Eki)").tag(25)
                        Text("100 MB (Discord / Hızlı)").tag(100)
                        Text("700 MB (CD-ROM)").tag(700)
                        Text("4000 MB (FAT32 / USB)").tag(4000)
                        Text("4700 MB (DVD)").tag(4700)
                    }
                    .labelsHidden()
                }
                .padding(.top, 2)
            }

            // SFX (Kendinden Açılan Arşiv)
            Toggle(isOn: $isSFX) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(supportsSFX ? .blue : .secondary)
                    Text("Kendinden Açılan Arşiv (SFX)")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .disabled(!supportsSFX)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Kaynakları Sil
            Toggle(isOn: $deleteSources) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    Text("Arşivleme Tamamlandıktan Sonra Kaynak Dosyaları Sil")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)

            // macOS Artıkları Temizliği
            Toggle(isOn: $stripMacJunk) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.mint)
                    Text("macOS Sistem Artıklarını Temizle (.DS_Store, __MACOSX)")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Dosya & Dizin Seçimi

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Seç"
        panel.message = "Arşivin kaydedileceği klasörü seçin:"

        if panel.runModal() == .OK, let url = panel.url {
            destinationDirectory = url
        }
    }

    private func chooseSourceFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Ekle"
        panel.message = "Sıkıştırılacak dosya ve klasörleri seçin:"

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            addSourceURLs(panel.urls)
        }
    }

    private func addSourceURLs(_ urls: [URL]) {
        var merged = currentSourceURLs
        for url in urls where !merged.contains(url) {
            merged.append(url)
        }
        currentSourceURLs = merged

        if archiveFileName.isEmpty || archiveFileName == "Yeni_Arşiv" {
            archiveFileName = merged.first?.deletingPathExtension().lastPathComponent ?? "Yeni_Arşiv"
        }

        Task {
            let stats = CompressionSimulator.shared.analyzeSources(urls: merged)
            await MainActor.run {
                withAnimation(.spring(response: 0.35)) {
                    self.sourceStats = stats
                }
            }
        }
    }

    private func handleDroppedFiles(providers: [NSItemProvider]) {
        var droppedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    droppedURLs.append(url)
                } else if let url = item as? URL {
                    droppedURLs.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            if !droppedURLs.isEmpty {
                self.addSourceURLs(droppedURLs)
            }
        }
    }
}
