import SwiftUI
import AppKit

@MainActor
private final class MenuBarDropZoneState: ObservableObject {
    @Published var isHovering: Bool = false
}

/// macOS Menü Çubuğu için Liquid Glass / Akrilik Mini Drop-Zone Widget'ı
@MainActor
public struct MenuBarDropZoneView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var state = MenuBarDropZoneState()
    public let onFileDropped: (URL) -> Void
    public let onOpenMainWindow: () -> Void
    public let onOpenArchivePicker: () -> Void
    public let onBrowseCompress: () -> Void

    public init(
        onFileDropped: @escaping (URL) -> Void,
        onOpenMainWindow: @escaping () -> Void,
        onOpenArchivePicker: @escaping () -> Void,
        onBrowseCompress: @escaping () -> Void
    ) {
        self.onFileDropped = onFileDropped
        self.onOpenMainWindow = onOpenMainWindow
        self.onOpenArchivePicker = onOpenArchivePicker
        self.onBrowseCompress = onBrowseCompress
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Başlık
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(settings.accentColorChoice.color)
                    Text("Coffer")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Button(action: onOpenMainWindow) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Ana Pencereyi Aç")
            }

            // Liquid Glass Mini Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        state.isHovering ? settings.accentColorChoice.color : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: state.isHovering ? 2 : 1.5, dash: state.isHovering ? [] : [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(state.isHovering ? settings.accentColorChoice.color.opacity(0.12) : Color.secondary.opacity(0.06))
                    )

                VStack(spacing: 6) {
                    Image(systemName: state.isHovering ? "arrow.down.doc.fill" : "archivebox.fill")
                        .font(.system(size: 24))
                        .foregroundColor(state.isHovering ? settings.accentColorChoice.color : .secondary)

                    Text(state.isHovering ? "Buraya Bırakın" : "Hızlı Bırakma Alanı")
                        .font(.system(size: 11, weight: .semibold))

                    Text("Arşivleri çıkartır veya yeni arşiv oluşturur")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 14)
            }
            .frame(height: 90)
            .onDrop(of: [.fileURL], isTargeted: $state.isHovering) { providers in
                if let provider = providers.first {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                onFileDropped(url)
                            }
                        }
                    }
                    return true
                }
                return false
            }

            Divider()

            // Hızlı Menü Eylemleri
            VStack(spacing: 4) {
                menuButton("Dosya Seç ve Sıkıştır...", icon: "plus.circle.fill") {
                    onBrowseCompress()
                }

                menuButton("Arşiv Aç...", icon: "folder.fill") {
                    onOpenArchivePicker()
                }

                menuButton("Coffer Uygulamasını Aç", icon: "macwindow") {
                    onOpenMainWindow()
                }

                Divider()

                menuButton("Çıkış", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 230)
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(settings.accentColorChoice.color)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12))

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
