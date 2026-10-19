import SwiftUI

/// Apple macOS tasarım standartlarına uygun, sade, zarif ve akıcı ilerleme penceresi
public struct ProgressModalView: View {
    @ObservedObject private var settings = AppSettings.shared

    public let title: String
    public let progress: ArchiveProgress
    public let onCancel: () -> Void

    @State private var isBreathing: Bool = false
    @State private var shimmerOffset: CGFloat = 0.0
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
            return "archivebox.fill"
        }
    }

    private var statusSubtitle: String {
        if !progress.currentFilename.isEmpty {
            return progress.currentFilename
        }
        return "Hazırlanıyor..."
    }

    public var body: some View {
        VStack(spacing: 16) {
            // 1. Üst Başlık Bölümü
            HStack(spacing: 14) {
                // Apple Tarzı Animasyonlu Rozet
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 46, height: 46)

                    if settings.enableAnimations {
                        Circle()
                            .fill(accentColor.opacity(0.16))
                            .frame(width: 36, height: 36)
                            .scaleEffect(isBreathing ? 1.15 : 0.85)
                            .blur(radius: 6)
                    }

                    Image(systemName: operationIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(accentColor)
                        .scaleEffect(settings.enableAnimations && isBreathing ? 1.05 : 0.98)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(statusSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(progress.percentageString)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
            }

            // 2. Zarif İlerleme Çubuğu
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let fillWidth = max(6, totalWidth * CGFloat(progress.fractionCompleted))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(NSColor.separatorColor).opacity(0.35))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress.fractionCompleted)

                    if settings.enableAnimations && progress.fractionCompleted > 0.05 && progress.fractionCompleted < 0.99 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(20, fillWidth * 0.3), height: 6)
                            .offset(x: (fillWidth - 20) * shimmerOffset)
                            .mask(
                                Capsule().frame(width: fillWidth, height: 6)
                            )
                    }
                }
            }
            .frame(height: 6)

            // 3. Bilgi ve Süre Satırı
            HStack(spacing: 6) {
                if progress.totalBytes > 1 {
                    Text("\(progress.formattedProcessedBytes) / \(progress.formattedTotalBytes)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    if progress.speedBytesPerSecond > 0 {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(progress.formattedSpeed)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let remaining = progress.estimatedRemainingTime, remaining > 0 {
                    Text("Kalan süre: \(progress.formattedRemainingTime)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else if !progress.formattedElapsedTime.isEmpty && progress.elapsedTime > 2 {
                    Text("Geçen süre: \(progress.formattedElapsedTime)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 4. İsteğe Bağlı İşlem Günlüğü (Ayrıntılar)
            if !progress.processedLog.isEmpty {
                DisclosureGroup(
                    isExpanded: $isLogExpanded,
                    content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(progress.processedLog.suffix(30).enumerated()), id: \.offset) { _, log in
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(accentColor)
                                        Text(log)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        }
                        .frame(maxHeight: 70)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    },
                    label: {
                        Text("Ayrıntılar (\(progress.processedLog.count))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                )
                .font(.system(size: 11))
            }

            // 5. Alt Aksiyon
            HStack {
                Spacer()

                Button("Vazgeç", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 12)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        guard settings.enableAnimations else { return }

        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            isBreathing = true
        }

        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.0
        }
    }
}
