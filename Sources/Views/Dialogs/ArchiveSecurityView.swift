import SwiftUI
import AppKit

public struct ArchiveSecurityView: View {
    @ObservedObject private var settings = AppSettings.shared
    public let report: ArchiveSecurityReport
    @Binding public var isPresented: Bool
    public var onSafeExtract: (() -> Void)? = nil
    public var onRegularExtract: (() -> Void)? = nil

    @State private var calculatedSHA256: String = ""
    @State private var calculatedMD5: String = ""
    @State private var isCalculatingHashes: Bool = false
    @State private var clipboardMatchStatus: ClipboardMatchState = .none
    @State private var selectedTab: SecurityTab = .overview
    @State private var expandedFindingIDs: Set<UUID> = []

    public enum SecurityTab: String, CaseIterable, Identifiable {
        case overview = "Genel Analiz"
        case findings = "Tespitler & Tehditler"
        case checksums = "Bütünlük (Hash)"

        public var id: String { rawValue }
    }

    private enum ClipboardMatchState {
        case none
        case matched(type: String)
        case mismatched(clipboardVal: String)
    }

    public init(
        report: ArchiveSecurityReport,
        isPresented: Binding<Bool>,
        onSafeExtract: (() -> Void)? = nil,
        onRegularExtract: (() -> Void)? = nil
    ) {
        self.report = report
        self._isPresented = isPresented
        self.onSafeExtract = onSafeExtract
        self.onRegularExtract = onRegularExtract
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Üst Başlık & Risk Rozeti
            headerView
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // MARK: - Sekme Seçici
            Picker("", selection: $selectedTab) {
                ForEach(SecurityTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // MARK: - Ana İçerik
            Group {
                switch selectedTab {
                case .overview:
                    overviewTabView
                case .findings:
                    findingsTabView
                case .checksums:
                    checksumsTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // MARK: - Alt Aksiyon Barı
            bottomActionBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 580, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            calculateHashesIfNeeded()
        }
    }

    // MARK: - Üst Başlık Bölümü

    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.14))
                    .frame(width: 48, height: 48)

                Image(systemName: report.riskLevel.systemIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(badgeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("UnPack Güvenlik & Risk Analizi")
                        .font(.system(size: 15, weight: .bold))

                    Text(report.riskLevel.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(badgeColor.opacity(0.14))
                        .foregroundColor(badgeColor)
                        .clipShape(Capsule())
                }

                Text(report.archiveURL.lastPathComponent)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Skor Göstergesi
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(report.safetyScore)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(badgeColor)
                Text("Güvenlik Skoru")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, 4)
        }
    }

    private var badgeColor: Color {
        switch report.riskLevel {
        case .safe: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }

    // MARK: - 1. Sekme: Genel Bakış

    private var overviewTabView: some View {
        ScrollView {
            VStack(spacing: 14) {
                // İstatistik Kartları Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statCard(
                        icon: "doc.on.doc.fill",
                        title: "Taranan İçerik",
                        value: "\(report.totalItems) Öğe",
                        subtitle: ByteCountFormatter.string(fromByteCount: report.totalUncompressedSize, countStyle: .file)
                    )

                    statCard(
                        icon: "arrow.down.right.and.arrow.up.left",
                        title: "Sıkıştırma Oranı",
                        value: String(format: "1:%.1f Kat", report.compressionRatio),
                        subtitle: report.compressionRatio > 40 ? "Olağan dışı yüksek" : "Normal seviyede"
                    )

                    statCard(
                        icon: "terminal.fill",
                        title: "Çalıştırılabilir & Betik",
                        value: "\(report.executableCount + report.scriptCount) Dosya",
                        subtitle: (report.executableCount + report.scriptCount) > 0 ? "İnceleme önerilir" : "Tehlikeli kod yok"
                    )

                    statCard(
                        icon: "network.badge.shield.half.filled",
                        title: "İnternet Karantinası",
                        value: report.hasQuarantineFlag ? "Mevcut" : "Yerel / Temiz",
                        subtitle: report.quarantineOriginAgent ?? "İndirme bayrağı yok"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Güvenlik Özeti Değerlendirme Kartı
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(badgeColor)
                            .font(.system(size: 13))
                        Text("Güvenlik Değerlendirmesi")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    Text(summaryEvaluationText)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(badgeColor.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Kritik Bulgu Uyarısı (Varsa)
                if let critical = report.findings.first(where: { $0.severity == .critical }) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(critical.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                            Text(critical.details)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func statCard(icon: String, title: String, value: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(settings.accentColorChoice.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private var summaryEvaluationText: String {
        switch report.riskLevel {
        case .safe:
            return "Arşiv analiz edildi; şüpheli sıkıştırma bombası kalıpları, sistem dizinini aşan yollar veya gizlenmiş yürütülebilir dosyalar bulunamadı. Gönül rahatlığıyla ayıklayabilirsiniz."
        case .warning:
            return "Arşiv içerisinde komut satırı betikleri veya olağan dışı sıkıştırma oranları tespit edildi. Kaynağına güveniyorsanız açabilirsiniz, şüpheli dosyaları çalıştırmamanız önerilir."
        case .danger:
            return "DİKKAT: Arşivde sistem kararlılığını veya güvenliğini tehdit edebilecek kritik bulgular saptandı (Zip Bomb, Zip Slip veya Sahte Uzantılı Yürütülebilir Dosyalar). Normal ayıklama yapmamanız tavsiye edilir."
        }
    }

    // MARK: - 2. Sekme: Tespitler ve Tehditler

    private var findingsTabView: some View {
        ScrollView {
            VStack(spacing: 10) {
                if report.findings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                            .padding(.top, 40)

                        Text("Herhangi Bir Risk Tespit Edilmedi")
                            .font(.system(size: 14, weight: .bold))

                        Text("Tüm dosyalar ve yollar standart parametrelere uygun.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(report.findings) { finding in
                        findingRow(finding: finding)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func findingRow(finding: SecurityFinding) -> some View {
        let isExpanded = expandedFindingIDs.contains(finding.id)
        let severityColor = colorForSeverity(finding.severity)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)

                Text(finding.category.rawValue)
                    .font(.system(size: 11, weight: .bold))

                Spacer()

                Text(finding.severity.rawValue)
                    .font(.system(size: 9.5, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.14))
                    .foregroundColor(severityColor)
                    .cornerRadius(4)
            }

            Text(finding.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            Text(finding.details)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(1.5)

            if !finding.affectedPaths.isEmpty {
                Button(action: {
                    if isExpanded {
                        expandedFindingIDs.remove(finding.id)
                    } else {
                        expandedFindingIDs.insert(finding.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Etkilenen Dosyaları Gizle" : "Etkilenen \(finding.affectedPaths.count) Dosyayı Göster")
                            .font(.system(size: 10.5, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(settings.accentColorChoice.color)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(finding.affectedPaths, id: \.self) { path in
                            Text("• \(path)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 9.5))
                Text(finding.recommendation)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(severityColor.opacity(0.4), lineWidth: 1)
        )
    }

    private func colorForSeverity(_ sev: FindingSeverity) -> Color {
        switch sev {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .teal
        }
    }

    // MARK: - 3. Sekme: Sağlama Toplamı (Hash) & Pano Doğrulama

    private var checksumsTabView: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Pano Eşleşme Bildirim Bandı
                clipboardMatchBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // SHA-256 Kartı
                hashRow(
                    name: "SHA-256",
                    hash: calculatedSHA256,
                    icon: "lock.shield.fill",
                    isBusy: isCalculatingHashes
                )
                .padding(.horizontal, 20)

                // MD5 Kartı
                hashRow(
                    name: "MD5",
                    hash: calculatedMD5,
                    icon: "number.circle.fill",
                    isBusy: isCalculatingHashes
                )
                .padding(.horizontal, 20)

                // Panodaki Değeri Tara Butonu
                Button(action: verifyClipboardHash) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard.fill")
                        Text("Panodaki Hash ile Karşılaştır")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .controlSize(.regular)
                .padding(.top, 4)
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var clipboardMatchBanner: some View {
        switch clipboardMatchStatus {
        case .none:
            EmptyView()
        case .matched(let type):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))

                Text("Panodaki \(type) değeriyle birebir eşleşti! Dosya orijinal ve bozulmamış.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .cornerRadius(7)
        case .mismatched(let clip):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Panodaki hash değeri uyuşmuyor!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                    Text("Pano: \(clip.prefix(20))...")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1))
            .cornerRadius(7)
        }
    }

    private func hashRow(name: String, hash: String, icon: String, isBusy: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(name, systemImage: icon)
                    .font(.system(size: 11.5, weight: .bold))
                Spacer()
                if isBusy {
                    ProgressView().controlSize(.small)
                } else if !hash.isEmpty {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hash, forType: .string)
                    }) {
                        Label("Kopyala", systemImage: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .controlSize(.small)
                }
            }

            if hash.isEmpty && isBusy {
                Text("Hesaplanıyor...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text(hash.isEmpty ? "Hesaplanamadı" : hash)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Alt Aksiyon Barı

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button("Kapat") {
                isPresented = false
            }
            .controlSize(.regular)

            Spacer()

            if report.hasCriticalRisk {
                Button(action: {
                    isPresented = false
                    onSafeExtract?()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.lefthalf.filled")
                        Text("Güvenli Ayıkla (Riskli Dosyaları Yalıt)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.regular)
            } else {
                Button(action: {
                    isPresented = false
                    onRegularExtract?()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Ayıkla...")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }

    // MARK: - Yardımcı Metotlar

    private func calculateHashesIfNeeded() {
        guard calculatedSHA256.isEmpty else { return }
        isCalculatingHashes = true
        Task {
            if let result = await ArchiveSecurityEngine.shared.calculateHashes(for: report.archiveURL) {
                await MainActor.run {
                    self.calculatedSHA256 = result.sha256
                    self.calculatedMD5 = result.md5
                    self.isCalculatingHashes = false
                    self.autoCheckClipboard(sha: result.sha256, md5: result.md5)
                }
            } else {
                await MainActor.run {
                    self.isCalculatingHashes = false
                }
            }
        }
    }

    private func autoCheckClipboard(sha: String, md5: String) {
        guard let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return }
        if clip.count == 64 && clip == sha.lowercased() {
            clipboardMatchStatus = .matched(type: "SHA-256")
        } else if clip.count == 32 && clip == md5.lowercased() {
            clipboardMatchStatus = .matched(type: "MD5")
        }
    }

    private func verifyClipboardHash() {
        guard let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return }
        if clip == calculatedSHA256.lowercased() {
            clipboardMatchStatus = .matched(type: "SHA-256")
        } else if clip == calculatedMD5.lowercased() {
            clipboardMatchStatus = .matched(type: "MD5")
        } else {
            clipboardMatchStatus = .mismatched(clipboardVal: clip)
        }
    }
}
