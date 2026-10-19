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
                .padding(.horizontal, 22)

            Divider()
                .padding(.top, 16)
                .padding(.bottom, 14)

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
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 460, height: 350)
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
        HStack(spacing: 14) {
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
                    .frame(width: 48, height: 48)
                    .shadow(color: accentColor.opacity(0.3), radius: 6, y: 3)

                Image(systemName: iconForCurrentState)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isPulsing && isDownloadingState ? 1.08 : 1.0)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(titleForCurrentState)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)

                Text(subtitleForCurrentState)
                    .font(.system(size: 11.5))
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
        VStack(alignment: .leading, spacing: 12) {
            // Sürüm Notları Kutusu
            VStack(alignment: .leading, spacing: 6) {
                Text("SÜRÜM NOTLARI & YENİLİKLER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                ScrollView(.vertical) {
                    Text(cleanReleaseNotes)
                        .font(.system(size: 11.5))
                        .foregroundColor(.primary.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 110)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
                )
            }

            Spacer()

            // Butonlar
            HStack {
                Button("Daha Sonra") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Spacer()

                Button {
                    Task {
                        await downloadManager.startDownloadAndInstall()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(downloadManager.isReinstall ? "Yeniden İndir ve Kur" : "Şimdi Güncelle ve Kur")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
            }
        }
    }

    private var cleanReleaseNotes: String {
        let body = downloadManager.releaseInfo?.body ?? ""
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Bu sürüm için özel sürüm notu girilmedi. Genel performans iyileştirmeleri ve hata düzeltmeleri içerir."
        }
        return body
    }

    // MARK: - 3. İndirme İlerleme Görünümü (.downloading)
    private func downloadingContentView(progress: Double, downloaded: Int64, total: Int64) -> some View {
        VStack(spacing: 16) {
            Spacer()

            // Özel Apple Tarzı İlerleme Çubuğu
            VStack(spacing: 8) {
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
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("%\(Int(progress * 100))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor)
                }
            }

            Text("İndirme devam ederken uygulamayı kullanmaya devam edebilirsiniz.")
                .font(.system(size: 11))
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
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("İndirilen disk kalıbı sağlama toplamı doğrulanıyor...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var installingContentView: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Coffer güncelleniyor ve kurulum tamamlanıyor...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            Text("Lütfen bekleyin, işlem birkaç saniye sürecektir.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 5. Tamamlandı Görünümü
    private var completedContentView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42))
                .foregroundColor(.green)

            Text("Güncelleme Başarıyla Tamamlandı!")
                .font(.system(size: 14, weight: .bold))

            Text("Coffer yeni sürümle yeniden başlatılıyor...")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 6. Hata Görünümü
    private func failedContentView(error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38))
                .foregroundColor(.red)

            Text("Güncelleme Başarısız")
                .font(.system(size: 14, weight: .bold))

            Text(error)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

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
