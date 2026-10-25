import SwiftUI
import UniformTypeIdentifiers

/// Apple macOS standartlarında, sade, ölçekli ve kaydırma gerektirmeyen Yeni Arşiv Oluşturma Penceresi
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
        let cleanName = archiveFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Arşiv" : archiveFileName
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
            return "Referans model"
        } else if currentSourceURLs.count == 1 {
            return "\(currentSourceURLs[0].lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: simulation.originalTotalSize, countStyle: .file)))"
        } else {
            return "\(currentSourceURLs.count) öğe (\(ByteCountFormatter.string(fromByteCount: simulation.originalTotalSize, countStyle: .file)))"
        }
    }

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
            // MARK: - 1. Başlık ve Dosya Ekleme
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            // RAR Aracı Eksik Uyarısı
            if isRarMissing {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(settings.accentColorChoice.color)
                    Text("RAR formatı için RAR aracı gereklidir.")
                        .font(.system(size: 11))
                    Spacer()
                    Button("İndir") {
                        if let url = URL(string: "https://www.rarlab.com/download.htm") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(settings.accentColorChoice.color.opacity(0.10))
                Divider()
            }

            // MARK: - 2. Ana Form İçeriği (Kaydırma Yok, Ekrana Tam Sığar)
            VStack(spacing: 12) {
                // Dosya Adı ve Format Seçici
                nameAndFormatRow

                // Hedef Klasör ve Sıkıştırma Düzeyi
                destinationAndLevelRow

                // Seçenekler & Güvenlik Izgarası (2 Sütunlu)
                optionsGridSection

                // Kompakt Canlı Boyut ve Tasarruf Paneli
                if settings.enableSizeSimulator {
                    compactEstimateBar
                }
            }
            .padding(18)

            Spacer(minLength: 0)

            Divider()

            // MARK: - 3. Alt Aksiyon Butonları
            footerActionSection
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 550, height: 475)
        .tint(settings.accentColorChoice.color)
    }

    // MARK: - 1. Başlık
    private var headerSection: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(settings.accentColorChoice.color.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: "archivebox.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(settings.accentColorChoice.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Yeni Arşiv Oluştur")
                    .font(.system(size: 14, weight: .semibold))

                Text(sourceSummaryText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: chooseSourceFiles) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Dosya Ekle")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - 2. İsim & Format
    private var nameAndFormatRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Arşiv Adı")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    TextField("Arşiv Adı", text: $archiveFileName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Text(".\(selectedFormat.primaryExtension)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(settings.accentColorChoice.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(settings.accentColorChoice.color.opacity(0.10))
                        )
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                Text("Biçim")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedFormat) {
                    Text("ZIP").tag(ArchiveFormat.zip)
                    Text("RAR").tag(ArchiveFormat.rar)
                    Text("7Z").tag(ArchiveFormat.sevenZip)
                    Text("TAR").tag(ArchiveFormat.tar)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }

    // MARK: - 3. Hedef Konum & Sıkıştırma Düzeyi
    private var destinationAndLevelRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Kayıt Konumu")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

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
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.8)
                )
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                Text("Sıkıştırma Düzeyi")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedLevel) {
                    ForEach(CompressionLevel.allCases) { lvl in
                        Text(lvl.title).tag(lvl)
                    }
                }
                .frame(width: 200)
            }
        }
    }

    // MARK: - 4. Seçenekler & Güvenlik Izgarası (2 Sütunlu Kompakt)
    private var optionsGridSection: some View {
        HStack(alignment: .top, spacing: 14) {
            // Sol Sütun: Güvenlik ve Katı Arşiv
            VStack(alignment: .leading, spacing: 9) {
                Toggle(isOn: $isPasswordProtected.animation(.spring(response: 0.25))) {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 11))
                            .foregroundColor(supportsEncryption ? settings.accentColorChoice.color : .secondary)
                        Text("Parola Koruması (AES-256)")
                            .font(.system(size: 11.5))
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(!supportsEncryption)

                if isPasswordProtected && supportsEncryption {
                    HStack(spacing: 6) {
                        SecureField("Parola belirleyin", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5))

                        if supportsHeaderEncryption {
                            Toggle("Adları Gizle", isOn: $encryptHeaders)
                                .font(.system(size: 10.5))
                                .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.leading, 18)
                }

                Toggle(isOn: $isSolid) {
                    HStack(spacing: 5) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 11))
                            .foregroundColor(supportsSolid ? .purple : .secondary)
                        Text("Katı Arşiv (Daha Yüksek Sıkıştırma)")
                            .font(.system(size: 11.5))
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(!supportsSolid)

                if supportsRecoveryRecord {
                    Toggle(isOn: $hasRecoveryRecord) {
                        HStack(spacing: 5) {
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text("Kurtarma Kaydı Ekle (%3)")
                                .font(.system(size: 11.5))
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sağ Sütun: Temizlik ve Ciltlere Bölme
            VStack(alignment: .leading, spacing: 9) {
                Toggle(isOn: $stripMacJunk) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(.mint)
                        Text("macOS Artıklarını Temizle (.DS_Store)")
                            .font(.system(size: 11.5))
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $deleteSources) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Text("Orijinal Dosyaları Sil")
                            .font(.system(size: 11.5))
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $isSplitArchive.animation(.spring(response: 0.25))) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: 11))
                            .foregroundColor(.indigo)
                        Text("Ciltlere Böl (Multi-volume)")
                            .font(.system(size: 11.5))
                    }
                }
                .toggleStyle(.checkbox)

                if isSplitArchive {
                    HStack(spacing: 6) {
                        Text("Cilt:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Picker("", selection: $splitVolumeSizeMB) {
                            Text("25 MB (E-posta)").tag(25)
                            Text("100 MB (Web)").tag(100)
                            Text("700 MB (CD)").tag(700)
                            Text("4 GB (FAT32)").tag(4000)
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }
                    .padding(.leading, 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.8)
        )
    }

    // MARK: - 5. Kompakt Canlı Boyut & Tasarruf Göstergesi
    private var compactEstimateBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Orijinal:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: simulation.originalTotalSize, countStyle: .file))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))

            HStack(spacing: 4) {
                Text("Tahmini:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: simulation.estimatedCompressedSize, countStyle: .file))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundColor(settings.accentColorChoice.color)
            }

            Spacer()

            if simulation.savingsPercentage > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("%\(String(format: "%.0f", simulation.savingsPercentage)) Tasarruf")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .foregroundColor(.green)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.6)
        )
    }

    // MARK: - 6. Alt Aksiyon Barı
    private var footerActionSection: some View {
        HStack(spacing: 12) {
            Button("Vazgeç") {
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
    }

    // MARK: - Dosya Seçimi
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
            currentSourceURLs.append(contentsOf: panel.urls)
            sourceStats = CompressionSimulator.shared.analyzeSources(urls: currentSourceURLs)
        }
    }
}
