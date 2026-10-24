import SwiftUI
import AppKit

/// GitHub Releases üzerinden yeni sürüm indirme ve kurulum ekranı
public struct UpdateDownloadDialog: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var downloadManager = UpdateDownloadManager.shared
    public let onDismiss: () -> Void

    @State private var isPulsing: Bool = false

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Başlık ve Rozet Bölümü
            headerSection
                .padding(.top, 22)
                .padding(.horizontal, 24)

            Divider()
                .padding(.top, 16)
                .padding(.bottom, 16)

            // Dinamik İçerik (Duruma Göre Değişen Aşama)
            VStack(spacing: 16) {
                switch downloadManager.state {
                case .prompt:
                    promptContentView
                case .downloading(let progress, let downloaded, let total):
                    downloadingContentView(progress: progress, downloaded: downloaded, total: total)
                case .verifying:
                    verifyingContentView
                case .installing:
                    installingContentView
                case .readyToRelaunch:
                    completedContentView
                case .failed(let error):
                    failedContentView(error: error)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 490)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if settings.enableAnimations {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    // MARK: - 1. Üst Başlık Bölümü
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Apple Tasarımlı Yuvarlatılmış Kare Simge
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.85), accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: accentColor.opacity(0.3), radius: 6, y: 3)

                Image(systemName: iconForCurrentState)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isPulsing && isDownloadingState ? 1.08 : 1.0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(titleForCurrentState)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Text(subtitleForCurrentState)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    private var isDownloadingState: Bool {
        if case .downloading = downloadManager.state { return true }
        return false
    }

    private var iconForCurrentState: String {
        switch downloadManager.state {
        case .prompt:
            return "arrow.triangle.2.circlepath"
        case .downloading:
            return "arrow.down.circle.fill"
        case .verifying, .installing:
            return "gearshape.2.fill"
        case .readyToRelaunch:
            return "checkmark.seal.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var titleForCurrentState: String {
        switch downloadManager.state {
        case .prompt:
            if downloadManager.isReinstall {
                return "Coffer Yeniden Kurulum"
            }
            return "Yeni Sürüm Mevcut: v\(downloadManager.releaseInfo?.version ?? "")"
        case .downloading:
            return "Coffer İndiriliyor..."
        case .verifying:
            return "Paket Doğrulanıyor..."
        case .installing:
            return "Coffer Güncelleniyor..."
        case .readyToRelaunch:
            return "Kurulum Başarılı!"
        case .failed:
            return "Güncelleme Başarısız"
        }
    }

    private var subtitleForCurrentState: String {
        switch downloadManager.state {
        case .prompt:
            return "Mevcut: v\(downloadManager.currentVersion) • Hedef: v\(downloadManager.releaseInfo?.version ?? "")"
        case .downloading:
            return "GitHub Releases üzerinden güvenli paket aktarımı yapılıyor."
        case .verifying:
            return "İndirilen disk görüntüsünün bütünlüğü kontrol ediliyor."
        case .installing:
            return "Yeni sürüm yerel uygulamayla değiştiriliyor ve kod imzası kontrol ediliyor."
        case .readyToRelaunch:
            return "Coffer yeni sürümle otomatik olarak yeniden başlatılacak."
        case .failed:
            return "Güncelleme paketi alınırken veya kurulurken bir sorun oluştu."
        }
    }

    // MARK: - 2. Sürüm Onayı ve Değişiklik Notları Görünümü (.prompt)
    private var promptContentView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Sürüm Notları Başlığı ve GitHub Bağlantısı
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(accentColor)
                    Text("SÜRÜM NOTLARI & YENİLİKLER")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let url = downloadManager.releaseInfo?.htmlURL {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("GitHub'da İncele")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentColor)
                    }
                }
            }

            // Gelişmiş Apple Tarzı Markdown Sürüm Notları
            ReleaseNotesMarkdownView(markdown: cleanReleaseNotes)
                .frame(maxWidth: .infinity)
                .frame(height: 270)

            Spacer()

            // Alt Butonlar
            HStack {
                Button("Daha Sonra") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Spacer()

                Button {
                    Task {
                        await downloadManager.startDownloadAndInstall()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(downloadManager.isReinstall ? "Yeniden İndir ve Kur" : "Şimdi Güncelle ve Kur")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var cleanReleaseNotes: String {
        let body = downloadManager.releaseInfo?.body ?? ""
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "### Genel Güncelleme\n* Bu sürüm genel performans iyileştirmeleri, bellek optimizasyonları ve kararlılık düzeltmeleri içerir.\n* Apple Silicon M1-M4 çipleri için uyumluluk güncellendi."
        }
        return body
    }

    // MARK: - 3. İndirme İlerleme Görünümü (.downloading)
    private func downloadingContentView(progress: Double, downloaded: Int64, total: Int64) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Özel Apple Tarzı İlerleme Çubuğu
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(NSColor.separatorColor).opacity(0.35))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.85), accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 10)
                            .animation(.easeOut(duration: 0.2), value: progress)
                    }
                }
                .frame(height: 10)

                // İstatistik Satırı (Boyut ve Yüzde)
                HStack {
                    Text("\(ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total > 0 ? total : downloaded, countStyle: .file))")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("%\(Int(progress * 100))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor)
                }
            }
            .padding(.horizontal, 10)

            Text("İndirme devam ederken uygulamayı kullanmaya devam edebilirsiniz.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack {
                Spacer()
                Button("İptal Et") {
                    downloadManager.cancel()
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    // MARK: - 4. Doğrulama ve Kurulum Aşamaları
    private var verifyingContentView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("İndirilen disk kalıbı sağlama toplamı doğrulanıyor...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var installingContentView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            VStack(spacing: 6) {
                Text("Coffer güncelleniyor ve kurulum tamamlanıyor...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Lütfen bekleyin, işlem birkaç saniye sürecektir.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - 5. Tamamlandı Görünümü
    private var completedContentView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundColor(.green)

            Text("Güncelleme Başarıyla Tamamlandı!")
                .font(.system(size: 16, weight: .bold))

            Text("Coffer yeni sürümle yeniden başlatılıyor...")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 6. Hata Görünümü
    private func failedContentView(error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(.red)

            Text("Güncelleme Başarısız")
                .font(.system(size: 16, weight: .bold))

            Text(error)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            HStack {
                Spacer()
                Button("Kapat") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
