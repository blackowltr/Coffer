import SwiftUI
import UniformTypeIdentifiers

/// Keka tarzı minimalist, hızlı sürükle-bırak (Drop Zone) ve Gözat modu
public struct DropZoneView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Binding public var isHovering: Bool
    public let onFilesDropped: ([URL]) -> Void
    public let onBrowseFiles: () -> Void
    public let onSwitchToExplorer: () -> Void

    public init(
        isHovering: Binding<Bool>,
        onFilesDropped: @escaping ([URL]) -> Void,
        onBrowseFiles: @escaping () -> Void,
        onSwitchToExplorer: @escaping () -> Void
    ) {
        self._isHovering = isHovering
        self.onFilesDropped = onFilesDropped
        self.onBrowseFiles = onBrowseFiles
        self.onSwitchToExplorer = onSwitchToExplorer
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Üst Başlık & Mod Geçişi
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(settings.accentColorChoice.color)
                    Text("Coffer Hızlı Mod")
                        .font(.headline)
                }

                Spacer()

                Button(action: onSwitchToExplorer) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow.on.rectangle")
                        Text("Gezgin Modu")
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Ana Bırakma Kutusu
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        isHovering ? settings.accentColorChoice.color : Color(NSColor.separatorColor),
                        style: StrokeStyle(lineWidth: isHovering ? 2.5 : 1.5, dash: isHovering ? [] : [8, 6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(isHovering ? settings.accentColorChoice.color.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                    )

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(settings.accentColorChoice.color.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .scaleEffect(isHovering ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3), value: isHovering)

                        Image(systemName: isHovering ? "arrow.down.doc.fill" : "archivebox.fill")
                            .font(.system(size: 36))
                            .foregroundColor(settings.accentColorChoice.color)
                    }

                    VStack(spacing: 6) {
                        Text(isHovering ? "Dosyaları Buraya Bırakın" : "Dosyaları veya Arşivleri Sürükleyin")
                            .font(.system(size: 16, weight: .bold))

                        Text("Arşiv dosyalarını otomatik olarak çıkartır; klasör ve belgeleri hızla sıkıştırır.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // Gözat Butonu
                    Button(action: onBrowseFiles) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("Dosya Seç (Gözat)...")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 12) {
                        badge("RAR")
                        badge("ZIP")
                        badge("7-Zip")
                        badge("TAR.GZ")
                    }
                    .padding(.top, 2)
                }
                .padding(28)
            }
            .frame(maxWidth: 480, maxHeight: 330)
            .padding(.horizontal, 24)
            .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                loadDroppedFiles(providers: providers)
                return true
            }

            Spacer()

            // Alt Bilgi
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("Hızlı, güvenli ve kayıpsız arşivleme")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(NSColor.quaternaryLabelColor))
            .cornerRadius(4)
            .foregroundStyle(.secondary)
    }

    private func loadDroppedFiles(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                onFilesDropped(urls)
            }
        }
    }
}
