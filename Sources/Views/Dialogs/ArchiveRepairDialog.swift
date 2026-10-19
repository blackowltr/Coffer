import SwiftUI
import AppKit

/// Hasarlı Arşivleri Onarma & Kurtarma Stüdyosu (Visual Archive Repair Studio)
public struct ArchiveRepairDialog: View {
    @ObservedObject private var settings = AppSettings.shared
    public let archiveURL: URL
    @Binding public var isPresented: Bool
    public let onRepairCompleted: (URL) -> Void

    @State private var isAnalyzing: Bool = true
    @State private var damageReport: ArchiveDamageReport? = nil
    @State private var selectedMode: ArchiveRepairMode = .aggressiveSalvage

    // Onarım Süreci Durumları
    @State private var isRepairing: Bool = false
    @State private var progressMessage: String = "Hazırlanıyor..."
    @State private var progressFraction: Double = 0.0
    @State private var liveLogs: [String] = []
    @State private var repairResult: ArchiveRepairResult? = nil
    @State private var errorMessage: String? = nil

    public init(
        archiveURL: URL,
        isPresented: Binding<Bool>,
        onRepairCompleted: @escaping (URL) -> Void
    ) {
        self.archiveURL = archiveURL
        self._isPresented = isPresented
        self.onRepairCompleted = onRepairCompleted
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Başlık
            headerView
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            // Ana Gövde
            if isAnalyzing {
                analyzingStateView
            } else if let result = repairResult {
                completedResultView(result)
            } else {
                repairConfigView
            }

            Divider()

            // Alt Butonlar
            bottomButtonsBar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 560, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            runDamageAnalysis()
        }
    }

    // MARK: - Başlık

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(settings.accentColorChoice.color.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(settings.accentColorChoice.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Hasarlı Arşiv Onarım Stüdyosu")
                    .font(.system(size: 15, weight: .bold))

                Text(archiveURL.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let report = damageReport {
                Text(report.damageSeverity.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(settings.accentColorChoice.color.opacity(0.15))
                    .foregroundColor(settings.accentColorChoice.color)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Analiz Durumu

    private var analyzingStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Arşiv sektörleri ve başlık tabloları taranıyor...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Onarım Ayarları ve Strateji Seçimi

    private var repairConfigView: some View {
        VStack(spacing: 14) {
            // Hasar Değerlendirme Kartı
            if let report = damageReport {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Arşiv Bütünlük Durumu")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Biçim: \(report.format) • Kurtarma Kaydı: \(report.hasRecoveryRecord ? "Mevcut" : "Yok")")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            statPill(title: "Tahmini Öğe", value: "\(report.totalEstimatedEntries)", color: .blue)
                            statPill(title: "Sağlam", value: "\(report.healthyEntriesCount)", color: .green)
                            statPill(title: "Hasarlı Blok", value: "\(report.damagedEntriesCount)", color: report.damagedEntriesCount > 0 ? .red : .secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(NSColor.separatorColor), lineWidth: 1))
            }

            // Strateji Seçici
            VStack(alignment: .leading, spacing: 8) {
                Text("Kurtarma Yöntemi Seçin:")
                    .font(.system(size: 11, weight: .semibold))

                ForEach(ArchiveRepairMode.allCases) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.25)) {
                            selectedMode = mode
                        }
                    }) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: selectedMode == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(selectedMode == mode ? settings.accentColorChoice.color : .secondary)
                                .font(.system(size: 13))
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(mode.description)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(selectedMode == mode ? settings.accentColorChoice.color.opacity(0.8) : Color(NSColor.separatorColor), lineWidth: selectedMode == mode ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Canlı İlerleme Çubuğu (Onarım Sırasında)
            if isRepairing {
                VStack(spacing: 6) {
                    ProgressView(value: progressFraction, total: 1.0)
                        .tint(settings.accentColorChoice.color)

                    HStack {
                        Text(progressMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(progressFraction * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Onarım Sonucu Ekranı

    private func completedResultView(_ result: ArchiveRepairResult) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
            }

            VStack(spacing: 4) {
                Text("Arşiv Onarımı Tamamlandı")
                    .font(.system(size: 18, weight: .bold))

                Text("\(result.salvagedFileCount) adet sağlam dosya kurtarıldı (\(ByteCountFormatter.string(fromByteCount: result.salvagedBytes, countStyle: .file)))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Çıktı Konumu Kartı
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundColor(settings.accentColorChoice.color)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.outputURL.lastPathComponent)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(result.outputURL.path)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Finder'da Göster") {
                    NSWorkspace.shared.selectFile(result.outputURL.path, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Alt Bar Butonları

    private var bottomButtonsBar: some View {
        HStack {
            Button("Kapat") {
                isPresented = false
            }
            .controlSize(.regular)
            .disabled(isRepairing)

            Spacer()

            if repairResult == nil {
                Button(action: startRepairAction) {
                    HStack(spacing: 6) {
                        if isRepairing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bandage.fill")
                        }
                        Text(isRepairing ? "Kurtarılıyor..." : "Onarımı Başlat")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isAnalyzing || isRepairing)
            } else {
                Button("Tamam") {
                    if let res = repairResult {
                        onRepairCompleted(res.outputURL)
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }

    // MARK: - Aksiyonlar

    private func runDamageAnalysis() {
        Task {
            let report = await ArchiveRepairEngine.shared.analyzeDamage(url: archiveURL)
            await MainActor.run {
                self.damageReport = report
                self.isAnalyzing = false
            }
        }
    }

    private func startRepairAction() {
        isRepairing = true
        progressFraction = 0.05
        progressMessage = "Kurtarma başlatılıyor..."

        Task {
            do {
                let result = try await ArchiveRepairEngine.shared.performRepair(
                    url: archiveURL,
                    mode: selectedMode,
                    onProgress: { msg, fraction in
                        Task { @MainActor in
                            self.progressMessage = msg
                            self.progressFraction = fraction
                        }
                    }
                )

                await MainActor.run {
                    self.repairResult = result
                    self.isRepairing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Onarım hatası: \(error.localizedDescription)"
                    self.isRepairing = false
                }
            }
        }
    }
}
