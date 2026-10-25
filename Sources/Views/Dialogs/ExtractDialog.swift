import SwiftUI

/// WinRAR tarzı "Dizine Çıkart..." ayarlar penceresi (Akıllı Çıkarma & Otomasyon Destekli)
public struct ExtractDialog: View {
    @ObservedObject private var settings = AppSettings.shared
    public let archiveName: String
    public let selectedItemsCount: Int
    @Binding public var isPresented: Bool
    public let onStartExtract: (URL, Bool, Bool, Bool, Bool) -> Void // (destURL, selectedOnly, overwrite, revealInFinder, trashOriginal)

    @State private var destinationDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    @State private var extractSelectedOnly: Bool = false
    @State private var overwriteExisting: Bool = true
    @State private var openInFinderAfter: Bool = true
    @State private var trashOriginalAfterExtract: Bool = false
    @State private var useSmartExtraction: Bool = true

    public init(
        archiveName: String,
        selectedItemsCount: Int,
        isPresented: Binding<Bool>,
        onStartExtract: @escaping (URL, Bool, Bool, Bool, Bool) -> Void
    ) {
        self.archiveName = archiveName
        self.selectedItemsCount = selectedItemsCount
        self._isPresented = isPresented
        self.onStartExtract = onStartExtract
        self._extractSelectedOnly = State(initialValue: selectedItemsCount > 0)
        self._useSmartExtraction = State(initialValue: AppSettings.shared.enableSmartExtraction)
        self._trashOriginalAfterExtract = State(initialValue: AppSettings.shared.trashArchiveAfterExtract)
        self._openInFinderAfter = State(initialValue: AppSettings.shared.revealInFinderAfterExtract)
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

            VStack(alignment: .leading, spacing: 16) {
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
                    }
                    .padding(6)
                }
            }
            .padding(18)

            Spacer()
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
                    onStartExtract(destinationDirectory, extractSelectedOnly, overwriteExisting, openInFinderAfter, trashOriginalAfterExtract)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
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
