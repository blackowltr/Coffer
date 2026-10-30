import SwiftUI

/// macOS Apple Human Interface Guidelines standartlarında alt durum ve kısayol çubuğu
public struct ArchiveFooterBar: View {
    @ObservedObject private var settings = AppSettings.shared
    public let totalItemsCount: Int
    public let totalUncompressedSize: Int64
    public let selectedItemsCount: Int
    public let selectedSize: Int64
    public let savingsRatio: Double
    public let metadata: ArchiveMetadata?

    public init(
        totalItemsCount: Int,
        totalUncompressedSize: Int64,
        selectedItemsCount: Int,
        selectedSize: Int64,
        savingsRatio: Double,
        metadata: ArchiveMetadata? = nil
    ) {
        self.totalItemsCount = totalItemsCount
        self.totalUncompressedSize = totalUncompressedSize
        self.selectedItemsCount = selectedItemsCount
        self.selectedSize = selectedSize
        self.savingsRatio = savingsRatio
        self.metadata = metadata
    }

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    public var body: some View {
        HStack(spacing: 10) {
            // MARK: 1. Seçim Durumu Kapsülü
            if selectedItemsCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accentColor)
                        .font(.system(size: 11))
                    Text("\(selectedItemsCount) seçili (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(accentColor.opacity(0.12))
                .clipShape(Capsule())
            }

            // MARK: 2. Toplam Öğe ve Boyut
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
                if let meta = metadata {
                    Text("\(totalItemsCount) öğe • \(meta.formattedUncompressedSize) (Paketli: \(meta.formattedArchiveSize))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(totalItemsCount) öğe • \(ByteCountFormatter.string(fromByteCount: totalUncompressedSize, countStyle: .file))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // MARK: 3. Tasarruf Oranı Rozeti
            if savingsRatio > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 9, weight: .bold))
                    Text("%\(String(format: "%.1f", savingsRatio)) Tasarruf")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.14))
                .foregroundColor(.green)
                .clipShape(Capsule())
            }

            Spacer()

            // MARK: 4. Format ve Arşiv Bayrakları
            if let meta = metadata {
                HStack(spacing: 6) {
                    LiquidGlassFormatBadge(format: meta.format, size: .small)

                    if meta.isSolid {
                        StatusFlagPill(text: "Katı (Solid)", color: .purple)
                    }

                    if meta.hasEncryptedHeaders {
                        StatusFlagPill(text: "Şifreli", icon: "lock.shield.fill", color: .orange)
                    }

                    if meta.isMultiVolume || meta.volumeCount > 1 {
                        StatusFlagPill(text: "\(meta.volumeCount) Cilt", color: .indigo)
                    }
                }
            }

            Divider()
                .frame(height: 12)

            // MARK: 5. Apple Klavye Kısayol İpuçları (Keycap Hints)
            HStack(spacing: 6) {
                KeycapHint(key: "␣", action: "Önizle")
                KeycapHint(key: "⌘E", action: "Çıkart")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            Color(NSColor.windowBackgroundColor)
                .opacity(0.85)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(NSColor.separatorColor).opacity(0.4)),
            alignment: .top
        )
    }
}

// MARK: - Durum Rozeti (macOS Tag)
private struct StatusFlagPill: View {
    let text: String
    var icon: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            if let ic = icon {
                Image(systemName: ic)
                    .font(.system(size: 8.5))
            }
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

// MARK: - Klavye Kısayol İpucu (Keycap Hint)
private struct KeycapHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(NSColor.quaternaryLabelColor).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                )

            Text(action)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
