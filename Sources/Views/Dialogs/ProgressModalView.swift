import SwiftUI

/// Apple macOS tasarım standartlarına uygun, Liquid Glass efektli, akıcı animasyonlu ve zarif Arşiv İşlem HUD'ı
public struct ProgressModalView: View {
    @ObservedObject private var settings = AppSettings.shared

    public let title: String
    public let progress: ArchiveProgress
    public let onCancel: () -> Void

    @State private var isSpinning: Bool = false
    @State private var isBreathing: Bool = false
    @State private var shimmerPhase: CGFloat = 0.0
    @State private var isLogExpanded: Bool = false

    public init(
        title: String,
        progress: ArchiveProgress,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.progress = progress
        self.onCancel = onCancel
    }

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    private var operationIcon: String {
        if title.contains("Çıkart") {
            return "tray.and.arrow.down.fill"
        } else if title.contains("Temizle") {
            return "sparkles"
        } else if title.contains("Test") {
            return "checkmark.shield.fill"
        } else if title.contains("Dönüştür") {
            return "arrow.triangle.2.circlepath"
        } else if title.contains("Şifre") {
            return "lock.fill"
        } else {
            return "doc.zipper"
        }
    }

    private var currentFileName: String {
        if !progress.currentFilename.isEmpty {
            return progress.currentFilename
        }
        return "Dosyalar taranıyor ve hazırlanıyor..."
    }

    public var body: some View {
        ZStack {
            // 1. Sahne Arkası Kromatik Işık Aurası (Ambient Backlight)
            if settings.enableAnimations {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(0.35),
                                accentColor.opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 180
                        )
                    )
                    .frame(width: 340, height: 340)
                    .scaleEffect(isBreathing ? 1.15 : 0.88)
                    .blur(radius: 28)
                    .offset(y: -20)
            }

            // 2. Ana Apple Liquid Glass HUD Kartı
            VStack(spacing: 18) {
                // Üst Görsel: Dönen Orbital İlerleme Halka Merkezi
                centralOrbitalHub

                // Başlık & Dinamik Dosya Satırı
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    // İşlenen Aktif Dosya Kapsülü
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 9))
                            .foregroundColor(accentColor)

                        Text(currentFileName)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
                    )
                }

                // Apple Tasarımlı Akıcı İlerleme Çubuğu (Shimmer & Glowing Tip)
                appleProgressBarSection

                // 3 Sütunlu Metrik Bilgi Panosu (İşlenen, Hız, Kalan)
                metricsDashboardGrid

                // Canlı İşlem Günlüğü (Ayrıntılar)
                if !progress.processedLog.isEmpty {
                    activityLogSection
                }

                // Alt Aksiyon Butonları
                HStack {
                    Spacer()

                    Button(action: onCancel) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Vazgeç")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(24)
            .frame(width: 460)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThickMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: 36, x: 0, y: 18)
        }
        .onAppear {
            startAppleAnimations()
        }
    }

    // MARK: - 1. Dönen Orbital İlerleme Halka Merkezi
    private var centralOrbitalHub: some View {
        ZStack {
            // Dış Dönen Kesikli Halka (Yörünge Animasyonu)
            if settings.enableAnimations {
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                accentColor.opacity(0.0),
                                accentColor.opacity(0.4),
                                accentColor,
                                accentColor.opacity(0.0)
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4, 6])
                    )
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
            }

            // İç Gerçek İlerleme Yayı
            Circle()
                .stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 4)
                .frame(width: 70, height: 70)

            Circle()
                .trim(from: 0, to: max(0.02, CGFloat(progress.fractionCompleted)))
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.85), accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress.fractionCompleted)

            // Merkezdeki 3D Cam İkon Kutusu
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.25),
                                accentColor.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: accentColor.opacity(0.25), radius: 8, y: 3)

                Image(systemName: operationIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(accentColor)
                    .scaleEffect(isBreathing ? 1.06 : 0.96)
            }
        }
        .frame(height: 86)
    }

    // MARK: - 2. Apple Tasarımlı İlerleme Çubuğu
    private var appleProgressBarSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let fillWidth = max(8, totalWidth * CGFloat(progress.fractionCompleted))

                ZStack(alignment: .leading) {
                    // Arka Plan Rayı
                    Capsule()
                        .fill(Color(NSColor.separatorColor).opacity(0.28))
                        .frame(height: 8)

                    // Dolgu Çubuğu
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.88)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress.fractionCompleted)

                    // Kayan Işık Dalgası (Apple Shimmer)
                    if settings.enableAnimations && progress.fractionCompleted > 0.04 && progress.fractionCompleted < 0.99 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.45),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(25, fillWidth * 0.35), height: 8)
                            .offset(x: (fillWidth - 25) * shimmerPhase)
                            .mask(
                                Capsule().frame(width: fillWidth, height: 8)
                            )
                    }

                    // Çubuk Ucu Işık Parıltısı
                    if fillWidth > 12 {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.white.opacity(0.8), radius: 3)
                            .offset(x: fillWidth - 7)
                    }
                }
            }
            .frame(height: 8)

            // Yüzde ve Hızlı Durum
            HStack {
                Text(progress.percentageString)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                Spacer()

                if progress.totalBytes > 1 {
                    Text("\(progress.formattedProcessedBytes) / \(progress.formattedTotalBytes)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 3. Üç Sütunlu Metrik Panosu
    private var metricsDashboardGrid: some View {
        HStack(spacing: 8) {
            metricCard(
                icon: "bolt.horizontal.fill",
                title: "HIZ",
                value: progress.speedBytesPerSecond > 0 ? progress.formattedSpeed : "Hesaplanıyor"
            )

            metricCard(
                icon: "timer",
                title: "KALAN SÜRE",
                value: (progress.estimatedRemainingTime ?? 0) > 0 ? progress.formattedRemainingTime : "00:00"
            )

            metricCard(
                icon: "clock.arrow.circlepath",
                title: "GEÇEN SÜRE",
                value: !progress.formattedElapsedTime.isEmpty ? progress.formattedElapsedTime : "00:01"
            )
        }
    }

    private func metricCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(accentColor.opacity(0.8))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - 4. Canlı İşlem Günlüğü
    private var activityLogSection: some View {
        DisclosureGroup(
            isExpanded: $isLogExpanded,
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(progress.processedLog.suffix(30).enumerated()), id: \.offset) { _, log in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                                Text(log)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .frame(maxHeight: 75)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
            },
            label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundColor(accentColor)
                    Text("İşlem Ayrıntıları (\(progress.processedLog.count) dosya)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        )
        .font(.system(size: 11))
    }

    // MARK: - 5. Animasyon Döngüleri
    private func startAppleAnimations() {
        guard settings.enableAnimations else { return }

        // Orbital Halka Sürekli Dönüşü (360 derece kesintisiz)
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
            isSpinning = true
        }

        // Cam İkon ve Işık Aurası Nefes Alma (Breathing Glow)
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            isBreathing = true
        }

        // Kayan Işık Dalgası
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.0
        }
    }
}
