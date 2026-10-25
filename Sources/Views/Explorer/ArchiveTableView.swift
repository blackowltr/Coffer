import SwiftUI
import UniformTypeIdentifiers

/// Apple macOS Human Interface Guidelines standartlarında zengin dosya tablosu
/// Sıralama, klavye gezintisi, boş durumlar ve mikro-etkileşimler desteklenir.
public struct ArchiveTableView: View {
    @ObservedObject private var settings = AppSettings.shared
    public let items: [ArchiveItem]
    @Binding public var selectedItemIDs: Set<UUID>
    public let onOpenDirectory: (String) -> Void
    public let onOpenFile: (ArchiveItem) -> Void
    public let onPreviewItem: (ArchiveItem) -> Void
    public let onExtractSelected: () -> Void
    public var onDragItem: ((ArchiveItem) -> NSItemProvider?)?

    @State private var sortOrder = [KeyPathComparator(\ArchiveItem.name)]
    @State private var sortedItems: [ArchiveItem] = []

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
        self._sortedItems = State(initialValue: items)
    }

    private func recalculateSortedItems() {
        if items.count > 300 {
            let order = sortOrder
            let inputItems = items
            Task.detached(priority: .userInitiated) {
                let result = inputItems.sorted(using: order)
                await MainActor.run {
                    self.sortedItems = result
                }
            }
        } else {
            sortedItems = items.sorted(using: sortOrder)
        }
    }

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    public var body: some View {
        Group {
            if items.isEmpty {
                emptyStateView
            } else {
                tableView
            }
        }
        .onAppear {
            recalculateSortedItems()
        }
        .onChange(of: items) { _, _ in
            recalculateSortedItems()
        }
        .onChange(of: sortOrder) { _, _ in
            recalculateSortedItems()
        }
    }

    // MARK: - 1. Boş Durum Görünümü (Apple Empty State)
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: "folder")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(accentColor.opacity(0.85))
            }

            VStack(spacing: 4) {
                Text("Klasör Boş")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Bu dizinde görüntülenecek herhangi bir dosya bulunmuyor.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor).opacity(0.4))
    }

    // MARK: - 2. Ana Tablo Görünümü
    private var tableView: some View {
        Table(sortedItems, selection: $selectedItemIDs, sortOrder: $sortOrder) {
            // 1. Kolon: Dosya Adı ve Kilit Göstergesi
            TableColumn("Dosya Adı", value: \ArchiveItem.name) { item in
                HStack(spacing: 8) {
                    Image(nsImage: FileIconProvider.shared.icon(for: item))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)

                    Text(item.name)
                        .font(.system(size: 12.5, weight: item.isDirectory ? .semibold : .regular))
                        .lineLimit(1)

                    if item.isEncrypted {
                        HStack(spacing: 2) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 9.5))
                            Text("Şifreli")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.orange.opacity(0.14))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                        .help("Parola Korumalı / Şifreli Dosya")
                    }

                    Spacer()

                    // Quick Look Önizleme Butonu
                    if !item.isDirectory {
                        Button(action: { onPreviewItem(item) }) {
                            Image(systemName: "eye.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
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
            .width(min: 220, ideal: 340)

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
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(accentColor.opacity(0.12))
                        .foregroundColor(accentColor)
                        .clipShape(Capsule())
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
            .width(min: 75, ideal: 85)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
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
