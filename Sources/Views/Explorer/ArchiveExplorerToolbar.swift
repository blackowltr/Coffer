import SwiftUI

/// macOS Sequoia ve Sonoma Human Interface Guidelines (HIG) standartlarında üst araç çubuğu
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

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // MARK: 1. Birincil Eylemler (Çıkart, Ekle, Sıkıştır)
                HStack(spacing: 6) {
                    Button(action: onExtract) {
                        Label("Dizine Çıkart", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .help("Seçili dosyaları veya tüm arşivi dizine çıkartın (⌘E)")

                    Button(action: onAddFiles) {
                        Label("Dosya Ekle", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Bu arşive yeni dosya veya klasörler ekleyin")

                    if let onNew = onNewArchive {
                        Button(action: onNew) {
                            Label("Sıkıştır", systemImage: "archivebox")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help("Yeni bir sıkıştırılmış arşiv paketi oluşturun")
                    }
                }

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)

                // MARK: 2. İnceleme ve Önizleme (Önizle, Test Et, Bilgi)
                HStack(spacing: 6) {
                    Button(action: onPreview) {
                        Image(systemName: "eye")
                            .frame(width: 22, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Quick Look ile Hızlı Önizleme (Boşluk)")

                    Button(action: onTestArchive) {
                        Image(systemName: "checkmark.shield")
                            .frame(width: 22, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Arşiv Bütünlüğünü Test Et (CRC Kontrolü)")

                    Button(action: onShowInfo) {
                        Image(systemName: "info.circle")
                            .frame(width: 22, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Arşiv Detayları ve Metadata Bilgisi (⌘I)")
                }

                Spacer()

                // MARK: 3. Görünüm Seçici (Segmented: Liste vs. Izgara)
                Picker("Görünüm", selection: $isGridView) {
                    Image(systemName: "list.bullet").tag(false)
                    Image(systemName: "square.grid.2x2").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 72)
                .help(isGridView ? "Izgara Görünümü" : "Liste Görünümü")

                // MARK: 4. Gelişmiş Araçlar Menüsü (•••)
                Menu {
                    Button(action: onConvertArchive) {
                        Label("Formatı Dönüştür (ZIP / 7Z / TAR)...", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(action: onDiffArchive) {
                        Label("İki Arşivi Karşılaştır (Diff)...", systemImage: "arrow.left.and.right")
                    }
                    Divider()
                    Button(action: onLockArchive) {
                        Label("Parola ile Kilitle...", systemImage: "lock.shield")
                    }
                    Button(action: onRepairArchive) {
                        Label("Hasarlı Arşivi Onar...", systemImage: "wrench.and.screwdriver")
                    }
                    if let showSec = onShowSecurity {
                        Divider()
                        Button(action: showSec) {
                            Label("Güvenlik & Tehdit Raporu...", systemImage: "shield.checkered")
                        }
                    }
                } label: {
                    Label("Araçlar", systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .controlSize(.regular)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                )
                .help("Gelişmiş Arşiv Araçları")

                // MARK: 5. Sil Butonu
                Button(action: onDeleteSelected) {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Seçili öğeleri arşivden sil")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()
        }
    }
}
