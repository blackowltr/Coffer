import SwiftUI

/// İki arşiv arasındaki farkları görsel olarak listeleyen karşılaştırma penceresi
public struct ArchiveDiffView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Binding public var isPresented: Bool
    public let initialArchiveURL: URL?

    @State private var archive1URL: URL?
    @State private var archive2URL: URL?
    @State private var diffResult: ArchiveDiffEngine.DiffResult? = nil
    @State private var isComparing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var selectedFilter: FilterTab = .all

    public enum FilterTab: String, CaseIterable, Identifiable {
        case all = "Tümü"
        case added = "Eklenenler"
        case removed = "Silinenler"
        case modified = "Değişenler"
        case unchanged = "Değişmeyenler"

        public var id: String { rawValue }
    }

    public init(isPresented: Binding<Bool>, initialArchiveURL: URL? = nil) {
        self._isPresented = isPresented
        self.initialArchiveURL = initialArchiveURL
        self._archive1URL = State(initialValue: initialArchiveURL)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Başlık
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(settings.accentColorChoice.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Arşiv Karşılaştırma & Fark (Diff) Aracı")
                        .font(.headline)
                    Text("İki arşiv arasındaki eklenen, silinen ve değişen dosyaları analiz edin.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button("Kapat") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Arşiv Seçim Alanı
            HStack(spacing: 16) {
                archivePickerBox(title: "1. Arşiv (Eski Sürüm)", url: $archive1URL)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)
                archivePickerBox(title: "2. Arşiv (Yeni Sürüm)", url: $archive2URL)

                Button(action: startComparison) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("Karşılaştır")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(archive1URL == nil || archive2URL == nil || isComparing)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Karşılaştırma Sonuçları
            if isComparing {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Arşivler taranıyor ve farklar hesaplanıyor...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let result = diffResult {
                VStack(spacing: 0) {
                    // Özet İstatistik Çubuğu & Filtreler
                    HStack(spacing: 12) {
                        filterPill(.all, count: result.totalDifferences + result.unchangedItems.count, color: .primary)
                        filterPill(.added, count: result.addedItems.count, color: .green)
                        filterPill(.removed, count: result.removedItems.count, color: .red)
                        filterPill(.modified, count: result.modifiedItems.count, color: .orange)
                        filterPill(.unchanged, count: result.unchangedItems.count, color: .secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))

                    Divider()

                    // Fark Tablosu
                    List {
                        ForEach(filteredEntries(result: result), id: \.id) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: entry.badgeIcon)
                                    .foregroundColor(entry.badgeColor)
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.path)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text(entry.detail)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(entry.statusText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(entry.badgeColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(entry.badgeColor.opacity(0.12))
                                    .cornerRadius(5)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Karşılaştırmak istediğiniz iki arşiv dosyasını seçin.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .frame(minWidth: 700, minHeight: 520)
    }

    private func archivePickerBox(title: String, url: Binding<URL?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack {
                Text(url.wrappedValue?.lastPathComponent ?? "Dosya seçilmedi")
                    .font(.system(size: 12))
                    .foregroundColor(url.wrappedValue == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("Seç...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        url.wrappedValue = panel.url
                    }
                }
                .font(.system(size: 11))
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
    }

    private func filterPill(_ tab: FilterTab, count: Int, color: Color) -> some View {
        Button(action: { selectedFilter = tab }) {
            HStack(spacing: 5) {
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: selectedFilter == tab ? .bold : .regular))

                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.2))
                    .cornerRadius(4)
            }
            .foregroundColor(selectedFilter == tab ? color : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(selectedFilter == tab ? color.opacity(0.12) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private struct DiffRowItem: Identifiable {
        let id = UUID()
        let path: String
        let detail: String
        let statusText: String
        let badgeIcon: String
        let badgeColor: Color
    }

    private func filteredEntries(result: ArchiveDiffEngine.DiffResult) -> [DiffRowItem] {
        var items: [DiffRowItem] = []

        if selectedFilter == .all || selectedFilter == .added {
            for item in result.addedItems {
                items.append(DiffRowItem(
                    path: item.path,
                    detail: "Yeni eklendi • \(item.formattedUncompressedSize)",
                    statusText: "+ Eklendi",
                    badgeIcon: "plus.circle.fill",
                    badgeColor: .green
                ))
            }
        }

        if selectedFilter == .all || selectedFilter == .removed {
            for item in result.removedItems {
                items.append(DiffRowItem(
                    path: item.path,
                    detail: "Eski sürümde vardı, yeni sürümde silindi • \(item.formattedUncompressedSize)",
                    statusText: "- Silindi",
                    badgeIcon: "minus.circle.fill",
                    badgeColor: .red
                ))
            }
        }

        if selectedFilter == .all || selectedFilter == .modified {
            for (oldItem, newItem) in result.modifiedItems {
                items.append(DiffRowItem(
                    path: newItem.path,
                    detail: "\(oldItem.formattedUncompressedSize) ➔ \(newItem.formattedUncompressedSize)",
                    statusText: "Δ Değişti",
                    badgeIcon: "pencil.circle.fill",
                    badgeColor: .orange
                ))
            }
        }

        if selectedFilter == .all || selectedFilter == .unchanged {
            for item in result.unchangedItems {
                items.append(DiffRowItem(
                    path: item.path,
                    detail: "Birebir aynı • \(item.formattedUncompressedSize)",
                    statusText: "= Değişmedi",
                    badgeIcon: "checkmark.circle.fill",
                    badgeColor: .secondary
                ))
            }
        }

        return items
    }

    private func startComparison() {
        guard let url1 = archive1URL, let url2 = archive2URL else { return }
        isComparing = true

        Task {
            do {
                let res = try await ArchiveDiffEngine.shared.compareArchives(archive1URL: url1, archive2URL: url2)
                await MainActor.run {
                    self.diffResult = res
                    self.isComparing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isComparing = false
                }
            }
        }
    }
}
