import SwiftUI

/// WinRAR tarzı "Dizine Çıkart..." ayarlar penceresi (Akıllı Çıkarma, Otomasyon & Alan Açma Destekli)
public struct ExtractDialog: View {
    @ObservedObject private var settings = AppSettings.shared
    public let archiveURL: URL?
    public let archiveName: String
    public let items: [ArchiveItem]
    public let selectedItemsCount: Int
    @Binding public var isPresented: Bool
    public let onStartExtract: (URL, Bool, Bool, Bool, Bool, Bool) -> Void // (destURL, selectedOnly, overwrite, revealInFinder, trashOriginal, useSpaceSaver)

    @State private var destinationDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    @State private var extractSelectedOnly: Bool = false
    @State private var overwriteExisting: Bool = true
    @State private var openInFinderAfter: Bool = true
    @State private var trashOriginalAfterExtract: Bool = false
    @State private var useSmartExtraction: Bool = true
    @State private var useSpaceSaverMode: Bool = false
    @State private var spaceReport: SpaceRequirementReport? = nil

    public init(
        archiveURL: URL? = nil,
        archiveName: String,
        items: [ArchiveItem] = [],
        selectedItemsCount: Int,
        isPresented: Binding<Bool>,
        onStartExtract: @escaping (URL, Bool, Bool, Bool, Bool, Bool) -> Void
    ) {
        self.archiveURL = archiveURL
        self.archiveName = archiveName
        self.items = items
        self.selectedItemsCount = selectedItemsCount
        self._isPresented = isPresented
        self.onStartExtract = onStartExtract
        self._extractSelectedOnly = State(initialValue: selectedItemsCount > 0)
        self._useSmartExtraction = State(initialValue: AppSettings.shared.enableSmartExtraction)
        self._trashOriginalAfterExtract = State(initialValue: AppSettings.shared.trashArchiveAfterExtract)
        self._openInFinderAfter = State(initialValue: AppSettings.shared.revealInFinderAfterExtract)
        self._useSpaceSaverMode = State(initialValue: AppSettings.shared.enableSpaceSaverMode)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Başlık
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 26))
                    .foregroundColor(settings.accentColorChoice.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dizine Çıkart")
                        .font(.headline)
                    Text(archiveName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Hedef Dizin
                    GroupBox("Hedef Dizin") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(destinationDirectory.path)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button("Gözat...") {
                                    chooseDestination()
                                }
                                .font(.system(size: 11))
                            }

                            // Hızlı Dizin Kısayolları
                            HStack(spacing: 8) {
                                quickLocationButton("Masaüstü", path: "Desktop")
                                quickLocationButton("İndirilenler", path: "Downloads")
                                quickLocationButton("Belgeler", path: "Documents")
                            }
                        }
                        .padding(6)
                    }

                    // Disk Alanı Analizi & Alan Açma Modu
                    if let report = spaceReport {
                        GroupBox("Disk Alanı & Alan Açma Analizi") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: report.canExtractStandard ? "internaldrive" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(report.canExtractStandard ? settings.accentColorChoice.color : .orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Boş Alan: \(report.availableDiskFormatted)")
                                                .font(.system(size: 11, weight: .semibold))
                                            Spacer()
                                            Text(report.statusBadgeText)
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(statusBadgeBackground(report.statusBadgeColorName))
                                                .foregroundColor(statusBadgeForeground(report.statusBadgeColorName))
                                                .cornerRadius(4)
                                        }

                                        HStack(spacing: 14) {
                                            Text("Standart Gerekli: \(report.standardRequiredFormatted)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)

                                            Text("Alan Açma Tepe İhtiyacı: \(report.spaceSaverRequiredFormatted)")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(settings.accentColorChoice.color)
                                        }
                                    }
                                }

                                Divider()

                                Toggle("⚡ Alan Açarak Çıkar (Düşük Disk Alanı Modu)", isOn: $useSpaceSaverMode)
                                    .font(.system(size: 12, weight: .medium))

                                Text("Arşivden çıkarılan dosyaların bloklarını anında serbest bırakarak (macOS APFS Blok Delme / Reverse Truncation) yetersiz disk alanında bile çıkarmayı sağlar.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 18)
                            }
                            .padding(6)
                        }
                    }

                    // Çıkarma Seçenekleri
                    GroupBox("Çıkarma Seçenekleri") {
                        VStack(alignment: .leading, spacing: 10) {
                            if selectedItemsCount > 0 {
                                Picker("Kapsam:", selection: $extractSelectedOnly) {
                                    Text("Tüm arşivi çıkart").tag(false)
                                    Text("Yalnızca seçili \(selectedItemsCount) öğeyi çıkart").tag(true)
                                }
                                .pickerStyle(.radioGroup)
                            }

                            Toggle("Otomatik Klasörleme (Dağılma Koruması)", isOn: $useSmartExtraction)
                                .font(.system(size: 12, weight: .medium))

                            Text("Arşivde dağınık dosyalar varsa otomatik yeni klasör açar; zaten tek bir klasör varsa fazladan klasör oluşturmaz.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 18)

                            Divider()

                            Toggle("Aynı isimdeki dosyaların üzerine yaz", isOn: $overwriteExisting)
                                .font(.system(size: 12))

                            Toggle("İşlem bittiğinde hedef klasörü Finder'da aç", isOn: $openInFinderAfter)
                                .font(.system(size: 12))

                            Toggle("İşlem tamamlanınca orijinal arşivi Çöp Sepeti'ne taşı", isOn: $trashOriginalAfterExtract)
                                .font(.system(size: 12))
                                .disabled(useSpaceSaverMode) // Alan açma modu zaten arşivi tüketir
                        }
                        .padding(6)
                    }
                }
                .padding(18)
            }

            Divider()

            // Alt Butonlar
            HStack {
                Button("İptal") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Çıkart") {
                    isPresented = false
                    onStartExtract(
                        destinationDirectory,
                        extractSelectedOnly,
                        overwriteExisting,
                        openInFinderAfter,
                        trashOriginalAfterExtract,
                        useSpaceSaverMode
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 520, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            recalculateSpace()
        }
        .onChange(of: destinationDirectory) {
            recalculateSpace()
        }
        .onChange(of: extractSelectedOnly) {
            recalculateSpace()
        }
    }

    private func recalculateSpace() {
        guard let arcURL = archiveURL else { return }
        let itemsToCheck = extractSelectedOnly ? items.prefix(selectedItemsCount).map { $0 } : items
        let report = SpaceRequirementEstimator.shared.evaluate(
            archiveURL: arcURL,
            destinationURL: destinationDirectory,
            items: itemsToCheck
        )
        self.spaceReport = report

        // Düşük disk alanı varsa ve kullanıcı otomatik modu açmışsa otomatik aktifleştir
        if report.isLowDiskSpace && settings.autoEnableSpaceSaverOnLowDisk {
            self.useSpaceSaverMode = true
        }
    }

    private func statusBadgeBackground(_ colorName: String) -> Color {
        switch colorName {
        case "green": return Color.green.opacity(0.18)
        case "orange": return Color.orange.opacity(0.18)
        case "yellow": return Color.yellow.opacity(0.18)
        default: return Color.gray.opacity(0.18)
        }
    }

    private func statusBadgeForeground(_ colorName: String) -> Color {
        switch colorName {
        case "green": return Color.green
        case "orange": return Color.orange
        case "yellow": return Color(red: 0.8, green: 0.6, blue: 0.0)
        default: return Color.secondary
        }
    }

    private func quickLocationButton(_ title: String, path: String) -> some View {
        Button(action: {
            destinationDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path)
        }) {
            Text(title)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Klasörü Seç"

        if panel.runModal() == .OK, let url = panel.url {
            destinationDirectory = url
        }
    }
}
