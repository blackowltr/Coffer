import SwiftUI

/// WinRAR tarzı alt durum çubuğu:
/// Dosya sayısı, toplam ve paketlenmiş boyut, format rozeti ve arşiv bayrakları (katı, şifreli başlıklar, ciltler).
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

    public var body: some View {
        HStack(spacing: 12) {
            // Seçili dosya bilgisi
            if selectedItemsCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(settings.accentColorChoice.color)
                        .font(.system(size: 11))
                    Text("Seçili: \(selectedItemsCount) (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))")
                        .font(.system(size: 11, weight: .medium))
                }
            } else {
                Text("Dosya seçilmedi")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 12)

            // Toplam dosya sayısı ve orijinal / paketlenmiş boyut
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                if let meta = metadata {
                    Text("Toplam: \(totalItemsCount) öğe • \(meta.formattedUncompressedSize) (Paketli: \(meta.formattedArchiveSize))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("Toplam: \(totalItemsCount) öğe (\(ByteCountFormatter.string(fromByteCount: totalUncompressedSize, countStyle: .file)))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Tasarruf oranı
            if savingsRatio > 0 {
                Divider()
                    .frame(height: 12)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    Text("%\(String(format: "%.1f", savingsRatio))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Format ve Bayraklar (Flags: Solid, Encrypted Headers, Volumes)
            if let meta = metadata {
                HStack(spacing: 6) {
                    // Format Rozeti
                    LiquidGlassFormatBadge(format: meta.format, size: .small)

                    // Solid Arşiv Bayrağı
                    if meta.isSolid {
                        Text("Katı / Solid")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }

                    // Şifreli Başlıklar Bayrağı
                    if meta.hasEncryptedHeaders {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 9))
                            Text("Şifreli Başlıklar")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(settings.accentColorChoice.color.opacity(0.12))
                        .foregroundColor(settings.accentColorChoice.color)
                        .cornerRadius(4)
                    }

                    // Çok Parçalı Arşiv (Volumes) Bayrağı
                    if meta.isMultiVolume || meta.volumeCount > 1 {
                        Text("Ciltler: \(meta.volumeCount)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.12))
                            .foregroundColor(.indigo)
                            .cornerRadius(4)
                    }
                }
            }

            // Durum Göstergesi
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Hazır")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .cornerRadius(5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(NSColor.windowBackgroundColor))
        .border(Color(NSColor.separatorColor), width: 0.5)
    }
}
