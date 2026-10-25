import SwiftUI
import AppKit

/// Apple Finder tarzı modern ve zarif Arşiv Izgara / Simge Görünümü (Icon / Grid View)
public struct ArchiveGridView: View {
    @ObservedObject private var settings = AppSettings.shared
    public let items: [ArchiveItem]
    @Binding public var selectedItemIDs: Set<UUID>
    public let onOpenDirectory: (String) -> Void
    public let onOpenFile: (ArchiveItem) -> Void
    public let onPreviewItem: (ArchiveItem) -> Void
    public let onExtractSelected: () -> Void
    public var onDragItem: ((ArchiveItem) -> NSItemProvider?)?

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 135), spacing: 12)
    ]

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

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    let isSelected = selectedItemIDs.contains(item.id)

                    GridItemCard(
                        item: item,
                        isSelected: isSelected,
                        accentColor: accentColor,
                        onDoubleTap: {
                            if item.isDirectory {
                                onOpenDirectory(item.path)
                            } else {
                                onOpenFile(item)
                            }
                        },
                        onSingleTap: {
                            if NSEvent.modifierFlags.contains(.command) {
                                if selectedItemIDs.contains(item.id) {
                                    selectedItemIDs.remove(item.id)
                                } else {
                                    selectedItemIDs.insert(item.id)
                                }
                            } else {
                                selectedItemIDs = [item.id]
                            }
                        },
                        onPreview: { onPreviewItem(item) },
                        onExtract: onExtractSelected,
                        onDragProvider: onDragItem?(item)
                    )
                }
            }
            .padding(16)
        }
        .background(Color(NSColor.textBackgroundColor).opacity(0.4))
        // Space -> Quick Look, Return -> Aç
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

// MARK: - Tekil Izgara Kartı (Apple Squircle Item Card)

private struct GridItemCard: View {
    let item: ArchiveItem
    let isSelected: Bool
    let accentColor: Color
    let onDoubleTap: () -> Void
    let onSingleTap: () -> Void
    let onPreview: () -> Void
    let onExtract: () -> Void
    let onDragProvider: NSItemProvider?

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // 1. Simge Alanı
            ZStack(alignment: .topTrailing) {
                Image(nsImage: FileIconProvider.shared.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(isSelected ? 0.25 : (isHovered ? 0.18 : 0.08)), radius: isHovered ? 6 : 3, y: 2)

                // Şifreli Arşiv Rozeti
                if item.isEncrypted {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .background(
                            Circle()
                                .fill(Color(NSColor.windowBackgroundColor))
                                .frame(width: 15, height: 15)
                        )
                        .offset(x: 4, y: -4)
                }
            }
            .frame(height: 56)

            // 2. Dosya Adı ve Bilgisi
            VStack(spacing: 3) {
                Text(item.name)
                    .font(.system(size: 12, weight: item.isDirectory ? .semibold : .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                    .frame(maxWidth: .infinity)

                if item.isDirectory {
                    Text("Klasör")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Text(item.formattedUncompressedSize)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)

                        if item.compressionRatio > 10 {
                            Text(item.formattedRatio)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(accentColor.opacity(0.12))
                                .foregroundColor(accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(minHeight: 125)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isSelected
                        ? accentColor.opacity(0.15)
                        : (isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.7) : Color(NSColor.controlBackgroundColor).opacity(0.35))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? accentColor.opacity(0.45)
                        : (isHovered ? Color(NSColor.separatorColor).opacity(0.4) : Color(NSColor.separatorColor).opacity(0.15)),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onSingleTap()
        }
        .onDrag {
            if let provider = onDragProvider {
                return provider
            }
            let provider = NSItemProvider(object: item.name as NSString)
            provider.suggestedName = item.name
            return provider
        }
        .contextMenu {
            if !item.isDirectory {
                Button("Varsayılan Uygulama ile Aç (Enter)") {
                    onDoubleTap()
                }
                Button("Quick Look ile Önizle (Boşluk)") {
                    onPreview()
                }
                Divider()
            }
            Button("Dizine Çıkart... (⌘E)") {
                onExtract()
            }
            if let crc = item.crc32 {
                Button("CRC32 Kopyala (\(crc))") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(crc, forType: .string)
                }
            }
        }
    }
}
