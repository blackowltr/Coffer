import SwiftUI
import UniformTypeIdentifiers

/// WinRAR tarzı detaylı dosya listesi tablosu
/// Başlıklara tıklayarak sıralama (hatırlanır), çift tıklama / Return ile varsayılan uygulamada açma,
/// Space tuşuyla Quick Look ve Masaüstüne Sürükle-Bırak destekli.
public struct ArchiveTableView: View {
    @ObservedObject private var settings = AppSettings.shared
    public let items: [ArchiveItem]
    @Binding public var selectedItemIDs: Set<UUID>
    public let onOpenDirectory: (String) -> Void
    public let onOpenFile: (ArchiveItem) -> Void
    public let onPreviewItem: (ArchiveItem) -> Void
    public let onExtractSelected: () -> Void
    public var onDragItem: ((ArchiveItem) -> NSItemProvider?)?

    @SceneStorage("macrar.table.sortComparator") private var sortComparatorKey: String = "name"
    @SceneStorage("macrar.table.sortAscending") private var sortAscending: Bool = true

    @State private var sortOrder = [KeyPathComparator(\ArchiveItem.name)]

    public init(
        items: [ArchiveItem],
        selectedItemIDs: Binding<Set<UUID>>,
        onOpenDirectory: @escaping (String) -> Void,
        onOpenFile: @escaping (ArchiveItem) -> Void,
        onPreviewItem: @escaping (ArchiveItem) -> Void,
        onExtractSelected: @escaping () -> Void,
        onDragItem: ((ArchiveItem) -> NSItemProvider?)? = nil
    ) {
        self.items = items
        self._selectedItemIDs = selectedItemIDs
        self.onOpenDirectory = onOpenDirectory
        self.onOpenFile = onOpenFile
        self.onPreviewItem = onPreviewItem
        self.onExtractSelected = onExtractSelected
        self.onDragItem = onDragItem
    }

    private var sortedItems: [ArchiveItem] {
        return items.sorted(using: sortOrder)
    }

    public var body: some View {
        Table(sortedItems, selection: $selectedItemIDs, sortOrder: $sortOrder) {
            // 1. Kolon: Dosya Adı ve Kilit Göstergesi
            TableColumn("Dosya Adı", value: \ArchiveItem.name) { item in
                HStack(spacing: 8) {
                    Image(nsImage: FileIconProvider.shared.icon(for: item))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 17, height: 17)

                    Text(item.name)
                        .font(.system(size: 13, weight: item.isDirectory ? .semibold : .regular))
                        .lineLimit(1)

                    if item.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(settings.accentColorChoice.color)
                            .help("Parola Korumalı / Şifreli")
                    }

                    Spacer()

                    // Quick Look Göz İkonu
                    if !item.isDirectory {
                        Button(action: { onPreviewItem(item) }) {
                            Image(systemName: "eye")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Quick Look ile Önizle (Boşluk)")
                    }
                }
                .contentShape(Rectangle())
                .onDrag {
                    if let provider = onDragItem?(item) {
                        return provider
                    }
                    let itemProvider = NSItemProvider(object: item.name as NSString)
                    itemProvider.suggestedName = item.name
                    return itemProvider
                }
                .onTapGesture(count: 2) {
                    if item.isDirectory {
                        onOpenDirectory(item.path)
                    } else {
                        onOpenFile(item)
                    }
                }
                .contextMenu {
                    if !item.isDirectory {
                        Button("Varsayılan Uygulama ile Aç (Enter)") {
                            onOpenFile(item)
                        }
                        Button("Quick Look ile Önizle (Boşluk)") {
                            onPreviewItem(item)
                        }
                        Divider()
                    }
                    Button("Dizine Çıkart... (⌘E)") {
                        onExtractSelected()
                    }
                    if let crc = item.crc32 {
                        Button("CRC32 Kopyala (\(crc))") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(crc, forType: .string)
                        }
                    }
                }
            }
            .width(min: 220, ideal: 320)

            // 2. Kolon: Orijinal Boyut
            TableColumn("Boyut", value: \ArchiveItem.uncompressedSize) { item in
                Text(item.formattedUncompressedSize)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)

            // 3. Kolon: Sıkıştırılmış Boyut
            TableColumn("Sıkıştırılmış", value: \ArchiveItem.compressedSize) { item in
                Text(item.formattedCompressedSize)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)

            // 4. Kolon: Sıkıştırma Oranı
            TableColumn("Oran", value: \ArchiveItem.compressionRatio) { item in
                if !item.isDirectory && item.uncompressedSize > 0 {
                    Text(item.formattedRatio)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(settings.accentColorChoice.color)
                } else {
                    Text("--")
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 65, ideal: 75)

            // 5. Kolon: Değiştirilme Tarihi
            TableColumn("Değiştirilme Tarihi", value: \ArchiveItem.modificationDateComparable) { item in
                if let date = item.modificationDate {
                    Text(date, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 120, ideal: 140)

            // 6. Kolon: CRC
            TableColumn("CRC", value: \ArchiveItem.crc32Sortable) { item in
                Text(item.crc32 ?? "--")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 90)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        // Space -> Quick Look, Return -> Varsayılan Uygulamada Aç / Klasöre Gir
        .onKeyPress(.space) {
            if let firstID = selectedItemIDs.first, let item = items.first(where: { $0.id == firstID }), !item.isDirectory {
                onPreviewItem(item)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if let firstID = selectedItemIDs.first, let item = items.first(where: { $0.id == firstID }) {
                if item.isDirectory {
                    onOpenDirectory(item.path)
                    return .handled
                } else {
                    onOpenFile(item)
                    return .handled
                }
            }
            return .ignored
        }
    }
}
