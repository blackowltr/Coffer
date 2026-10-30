import SwiftUI

/// Apple macOS Human Interface Guidelines (HIG) standartlarında Arşiv İşlem İlerleme Paneli
public struct ProgressModalView: View {
    @ObservedObject private var settings = AppSettings.shared

    public let title: String
    public let progress: ArchiveProgress
    public let onCancel: () -> Void

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
        VStack(spacing: 16) {
            // 1. Üst İkon & Başlık Alanı
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: operationIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(currentFileName)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }

            // 2. İlerleme Çubuğu & Yüzde
            VStack(spacing: 6) {
                ProgressView(value: max(0.01, progress.fractionCompleted))
                    .progressViewStyle(.linear)
                    .tint(accentColor)

                HStack {
                    Text(progress.percentageString)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)

                    Spacer()

                    if progress.totalBytes > 1 {
                        Text("\(progress.formattedProcessedBytes) / \(progress.formattedTotalBytes)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 3. Metrik Panosu
            metricsDashboardGrid

            // 4. Canlı Günlük (Opsiyonel Açılır Kapanır)
            if !progress.processedLog.isEmpty {
                activityLogSection
            }

            // 5. Alt Aksiyon Butonu
            HStack {
                Spacer()

                Button(action: onCancel) {
                    Text("Vazgeç")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
    }

    // MARK: - Metrik Panosu
    private var metricsDashboardGrid: some View {
        HStack(spacing: 8) {
            metricItem(
                icon: "doc.on.doc",
                title: "Dosyalar",
                value: "\(progress.processedLog.count) dosya"
            )

            metricItem(
                icon: "speedometer",
                title: "Hız",
                value: progress.formattedSpeed
            )

            metricItem(
                icon: "clock",
                title: "Kalan",
                value: progress.formattedRemainingTime
            )

            if progress.freedBytes > 0 {
                metricItem(
                    icon: "externaldrive.badge.checkmark",
                    title: "Açılan Alan",
                    value: progress.formattedFreedBytes
                )
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func metricItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Günlük Bölümü
    private var activityLogSection: some View {
        DisclosureGroup(
            isExpanded: $isLogExpanded,
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(progress.processedLog.suffix(15).enumerated()), id: \.offset) { _, log in
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
                .frame(maxHeight: 70)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)
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
}
