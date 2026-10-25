import SwiftUI

/// macOS Sequoia ve Sonoma tasarım diline uygun, yarı saydam cam kapsüllü Apple Üst Araç Çubuğu
public struct ArchiveExplorerToolbar: View {
    @ObservedObject private var settings = AppSettings.shared

    public let onExtract: () -> Void
    public let onAddFiles: () -> Void
    public let onTestArchive: () -> Void
    public let onPreview: () -> Void
    public let onDeleteSelected: () -> Void
    public let onShowInfo: () -> Void
    public let onConvertArchive: () -> Void
    public let onDiffArchive: () -> Void
    public let onLockArchive: () -> Void
    public let onRepairArchive: () -> Void
    public let onShowSecurity: (() -> Void)?
    public let onNewArchive: (() -> Void)?

    @Binding public var isGridView: Bool

    public init(
        onExtract: @escaping () -> Void,
        onAddFiles: @escaping () -> Void,
        onTestArchive: @escaping () -> Void,
        onPreview: @escaping () -> Void,
        onDeleteSelected: @escaping () -> Void,
        onShowInfo: @escaping () -> Void,
        onConvertArchive: @escaping () -> Void,
        onDiffArchive: @escaping () -> Void,
        onLockArchive: @escaping () -> Void,
        onRepairArchive: @escaping () -> Void,
        onShowSecurity: (() -> Void)?,
        onNewArchive: (() -> Void)?,
        isGridView: Binding<Bool>
    ) {
        self.onExtract = onExtract
        self.onAddFiles = onAddFiles
        self.onTestArchive = onTestArchive
        self.onPreview = onPreview
        self.onDeleteSelected = onDeleteSelected
        self.onShowInfo = onShowInfo
        self.onConvertArchive = onConvertArchive
        self.onDiffArchive = onDiffArchive
        self.onLockArchive = onLockArchive
        self.onRepairArchive = onRepairArchive
        self.onShowSecurity = onShowSecurity
        self.onNewArchive = onNewArchive
        self._isGridView = isGridView
    }

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    public var body: some View {
        HStack(spacing: 10) {
            // MARK: 1. Ana İşlem Kapsülü (Dizine Çıkart, Dosya Ekle, Sıkıştır)
            HStack(spacing: 4) {
                // Dizine Çıkart (Vurgulu Birincil Eylem)
                Button(action: onExtract) {
                    HStack(spacing: 5) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Dizine Çıkart")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: accentColor.opacity(0.3), radius: 3, y: 1.5)
                }
                .buttonStyle(.plain)
                .help("Seçili dosyaları veya tüm arşivi dizine çıkartın (⌘E)")

                // Dosya Ekle
                AppleCapsuleButton(title: "Dosya Ekle", icon: "doc.badge.plus", tint: .green, action: onAddFiles)
                    .help("Bu arşive yeni dosya veya klasörler ekleyin")

                // Yeni Sıkıştırma
                if let onNew = onNewArchive {
                    AppleCapsuleButton(title: "Sıkıştır", icon: "archivebox.circle.fill", tint: .teal, action: onNew)
                        .help("Yeni bir sıkıştırılmış arşiv paketi oluşturun")
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )

            // MARK: 2. İnceleme ve Önizleme Kapsülü (Önizle, Test, Bilgi)
            HStack(spacing: 3) {
                AppleCapsuleIconButton(icon: "eye.fill", tooltip: "Quick Look ile Hızlı Önizleme (Boşluk)", tint: .indigo, action: onPreview)
                AppleCapsuleIconButton(icon: "checkmark.shield.fill", tooltip: "Arşiv Bütünlüğünü Test Et (CRC Kontrolü)", tint: .purple, action: onTestArchive)
                AppleCapsuleIconButton(icon: "info.circle.fill", tooltip: "Arşiv Detayları ve Metadata Bilgisi (⌘I)", tint: .cyan, action: onShowInfo)
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )

            Spacer()

            // MARK: 3. Görünüm Seçici (Liste vs. Izgara)
            HStack(spacing: 2) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isGridView = false
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11, weight: !isGridView ? .bold : .medium))
                        .foregroundColor(!isGridView ? .primary : .secondary)
                        .frame(width: 26, height: 22)
                        .background(!isGridView ? Color(NSColor.selectedControlColor).opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Liste Görünümü")

                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isGridView = true
                    }
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11, weight: isGridView ? .bold : .medium))
                        .foregroundColor(isGridView ? .primary : .secondary)
                        .frame(width: 26, height: 22)
                        .background(isGridView ? Color(NSColor.selectedControlColor).opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Izgara (Simge) Görünümü")
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )

            // MARK: 4. Gelişmiş Araçlar Menüsü (•••)
            Menu {
                Button(action: onConvertArchive) {
                    Label("Formatı Dönüştür (Zip/7z/Tar)...", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(action: onDiffArchive) {
                    Label("İki Arşivi Karşılaştır (Diff)...", systemImage: "arrow.left.and.right")
                }
                Divider()
                Button(action: onLockArchive) {
                    Label("Parola ile Kilitle...", systemImage: "lock.shield.fill")
                }
                Button(action: onRepairArchive) {
                    Label("Hasarlı Arşivi Onar...", systemImage: "wrench.and.screwdriver.fill")
                }
                if let showSec = onShowSecurity {
                    Divider()
                    Button(action: showSec) {
                        Label("Güvenlik & Tehdit Raporu...", systemImage: "shield.checkered")
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                    Text("Araçlar")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
                )
            }
            .menuStyle(.borderlessButton)
            .help("Gelişmiş Arşiv Araçları")

            // Sil Butonu
            Button(action: onDeleteSelected) {
                Image(systemName: "trash")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Seçili öğeleri arşivden sil")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Color(NSColor.windowBackgroundColor)
                .opacity(0.85)
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Apple Kapsül Metin Butonu
private struct AppleCapsuleButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isHovered ? tint.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Apple Kapsül Simge Butonu
private struct AppleCapsuleIconButton: View {
    let icon: String
    let tooltip: String
    let tint: Color
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isHovered ? tint : .secondary)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? tint.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}
