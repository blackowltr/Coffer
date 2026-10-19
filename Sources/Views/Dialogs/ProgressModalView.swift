import SwiftUI

/// Apple Silicon ve macOS Sequoia tasarım diline uygun, lüks cam efektli ve akıcı animasyonlu sıkıştırma / çıkarma HUD penceresi
public struct ProgressModalView: View {
    @ObservedObject private var settings = AppSettings.shared

    public let title: String
    public let progress: ArchiveProgress
    public let onCancel: () -> Void

    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var wavePhase: CGFloat = 0.0
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

    public var body: some View {
        VStack(spacing: 20) {
            // 1. Üst Bölüm: Canlı Sıkıştırma Reaktörü & Durum Başlığı
            HStack(spacing: 18) {
                // Sıkıştırma Reaktör Animasyonu
                compressionReactorView

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Text(progress.percentageString)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)

                        Text("tamamlandı")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Text("Kayıpsız sıkıştırma ve veri akışı aktif")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()
            }

            // 2. Işıltılı ve Parıltılı İlerleme Çubuğu (Shimmer Liquid Bar)
            VStack(spacing: 8) {
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let fillWidth = max(14, totalWidth * CGFloat(progress.fractionCompleted))

                    ZStack(alignment: .leading) {
                        // Derin Arka Plan Kanalı
                        Capsule()
                            .fill(Color(NSColor.separatorColor).opacity(0.4))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                            .frame(height: 12)

                        // Doldurulan Canlı Alan
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.85),
                                        accentColor,
                                        accentColor.opacity(0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillWidth, height: 12)
                            .shadow(color: accentColor.opacity(0.45), radius: 8, x: 0, y: 2)

                        // İlerleme Üzerindeki Işık Dalgası (Shimmer Efekti)
                        if settings.enableAnimations && progress.fractionCompleted > 0.05 {
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
                                .frame(width: max(30, fillWidth * 0.35), height: 12)
                                .offset(x: fillWidth * shimmerOffset)
                                .mask(
                                    Capsule()
                                        .frame(width: fillWidth, height: 12)
                                )
                        }

                        // Uç Nokta Parıltı Göstergesi (Leading Glow Dot)
                        if fillWidth > 14 {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .shadow(color: Color.white, radius: 4)
                                .offset(x: fillWidth - 9)
                        }
                    }
                }
                .frame(height: 12)
            }

            // 3. Zengin Telemetri ve Performans Kartı (Geçen Süre, Kalan Süre, Hız, Boyut)
            HStack(spacing: 0) {
                telemetryCell(
                    icon: "timer",
                    iconColor: .indigo,
                    label: "GEÇEN SÜRE",
                    value: progress.formattedElapsedTime
                )

                Divider()
                    .frame(height: 32)

                telemetryCell(
                    icon: "clock.fill",
                    iconColor: .blue,
                    label: "KALAN SÜRE",
                    value: progress.formattedRemainingTime
                )

                Divider()
                    .frame(height: 32)

                telemetryCell(
                    icon: "bolt.fill",
                    iconColor: accentColor,
                    label: "İŞLEM HIZI",
                    value: progress.formattedSpeed
                )

                Divider()
                    .frame(height: 32)

                telemetryCell(
                    icon: "internaldrive.fill",
                    iconColor: .green,
                    label: "İŞLENEN VERİ",
                    value: "\(progress.formattedProcessedBytes) / \(progress.formattedTotalBytes)"
                )
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )

            // 4. Anlık İşlenen Dosya Akışı Kutusu
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 11))
                    .foregroundColor(accentColor)

                Text(progress.currentFilename.isEmpty ? "Arşiv indeksleniyor..." : progress.currentFilename)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundColor(accentColor.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )

            // 5. Genişletilebilir İşlenen Dosyalar Kayıt Günlüğü (Collapsible Log)
            if !progress.processedLog.isEmpty {
                DisclosureGroup(
                    isExpanded: $isLogExpanded,
                    content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(progress.processedLog.enumerated()), id: \.offset) { _, log in
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.green.opacity(0.8))
                                        Text(log)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                        }
                        .frame(maxHeight: 90)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    },
                    label: {
                        HStack(spacing: 6) {
                            Text("İşlenen Dosyaların Kaydı (\(progress.processedLog.count))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                )
                .padding(.horizontal, 4)
            }

            // 5. Alt Bölüm: İptal Et Butonu
            HStack {
                Spacer()

                Button(action: onCancel) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                        Text("Durdur ve İptal Et")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(
            ZStack {
                // Ultra Thin Frosted Cam Arka Plan
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)

                // İpeksi Derin Pencere Zemin Rengi
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor))

                // Üst Kısımdan Süzülen Ortam Işığı (Ambient Glow)
                RadialGradient(
                    colors: [
                        accentColor.opacity(0.14),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 10,
                    endRadius: 260
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 30, x: 0, y: 15)
        .shadow(color: accentColor.opacity(0.15), radius: 20, x: 0, y: 5)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Merkezi Sıkıştırma Reaktörü (Mechanical / Particle Core)

    private var compressionReactorView: some View {
        ZStack {
            // Dış Dönen Kesikli Çember
            Circle()
                .strokeBorder(
                    accentColor.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(outerRotation))

            // İç Ters Dönen Çember
            Circle()
                .strokeBorder(
                    accentColor.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                )
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(innerRotation))

            // Basınç Dalgası Halka (Inward Compressing Wave)
            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
                .frame(width: 36, height: 36)
                .scaleEffect(pulseScale)

            // Merkez Çekirdek
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.3),
                            accentColor.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)
                .shadow(color: accentColor.opacity(0.4), radius: 6)

            Image(systemName: "doc.zipper")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(accentColor)
        }
        .frame(width: 56, height: 56)
    }

    // MARK: - Telemetri Hücresi

    private func telemetryCell(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(iconColor)

                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Animasyon Tetikleyicileri

    private func startAnimations() {
        guard settings.enableAnimations else { return }

        // Dış halka dönüşü
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            outerRotation = 360
        }

        // İç halka ters dönüşü
        withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
            innerRotation = -360
        }

        // Basınç nabzı
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        // Işık süpürme (Shimmer)
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.2
        }
    }
}
