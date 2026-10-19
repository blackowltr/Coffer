import SwiftUI
import AppKit

/// Coffer uygulamasının gerçek arayüz bileşenlerini 2x Retina kalitesinde PNG olarak çıkaran görsel üretici
@MainActor
public final class ScreenshotGenerator {

    public static func generateAll(outputDir: String) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        print("==> Gerçek Coffer ekran görüntüleri üretiliyor...")

        // 1. Ana Arşiv Gezgini Ekranı (Explorer Window)
        generateExplorerScreenshot(targetPath: "\(outputDir)/screenshot-explorer.png")

        // 2. Ayarlar & Hakkında Ekranı (Settings / About Window)
        generateSettingsScreenshot(targetPath: "\(outputDir)/screenshot-settings.png")

        // 3. Güncelleme İndirme Ekranı (In-App Updater Window)
        generateUpdaterScreenshot(targetPath: "\(outputDir)/screenshot-updater.png")

        // 4. Hızlı Bırakma / Drop Zone Ekranı (Drop Zone Window)
        generateDropZoneScreenshot(targetPath: "\(outputDir)/screenshot-quickdrop.png")

        print("==> Tüm gerçek ekran görüntüleri başarıyla üretildi: \(outputDir)")
    }

    // MARK: - 1. Ana Gezgin Penceresi
    private static func generateExplorerScreenshot(targetPath: String) {
        let sampleItems: [ArchiveItem] = [
            ArchiveItem(
                path: "Sources/Engine/ArchiveEngine.swift",
                uncompressedSize: 34_820,
                compressedSize: 11_240,
                modificationDate: Date(timeIntervalSince1970: 1792410000),
                isDirectory: false,
                isEncrypted: false,
                crc32: "A4F89B12"
            ),
            ArchiveItem(
                path: "Sources/Config/SecretKeys.env",
                uncompressedSize: 2_450,
                compressedSize: 810,
                modificationDate: Date(timeIntervalSince1970: 1792400000),
                isDirectory: false,
                isEncrypted: true,
                crc32: "7E8F9A0B"
            ),
            ArchiveItem(
                path: "Sources/Views/Components/LiquidGlassDesign.swift",
                uncompressedSize: 18_920,
                compressedSize: 6_450,
                modificationDate: Date(timeIntervalSince1970: 1792390000),
                isDirectory: false,
                isEncrypted: false,
                crc32: "B3C5D7E9"
            ),
            ArchiveItem(
                path: "Sources/Core/UpdateDownloadManager.swift",
                uncompressedSize: 14_210,
                compressedSize: 4_320,
                modificationDate: Date(timeIntervalSince1970: 1792380000),
                isDirectory: false,
                isEncrypted: false,
                crc32: "F1E2D3C4"
            ),
            ArchiveItem(
                path: "Resources/Logo_Master_1024.png",
                uncompressedSize: 1_420_000,
                compressedSize: 1_120_000,
                modificationDate: Date(timeIntervalSince1970: 1792350000),
                isDirectory: false,
                isEncrypted: false,
                crc32: "1A2B3C4D"
            ),
            ArchiveItem(
                path: "Documentation/Kullanim_Rehberi.pdf",
                uncompressedSize: 284_000,
                compressedSize: 215_000,
                modificationDate: Date(timeIntervalSince1970: 1792300000),
                isDirectory: false,
                isEncrypted: false,
                crc32: "5E6F7A8B"
            )
        ]

        let meta = ArchiveMetadata(
            format: .rar,
            archiveURL: URL(fileURLWithPath: "/Users/developer/Downloads/Coffer_Source_v1.0.0.rar"),
            totalFileCount: 6,
            totalDirectoryCount: 2,
            totalUncompressedSize: 1_774_400,
            archiveFileSize: 1_357_820,
            isEncrypted: true,
            hasEncryptedHeaders: true,
            isSolid: true,
            isMultiVolume: false,
            volumeCount: 1,
            hasRecoveryRecord: true,
            recoveryRecordPercentage: 3,
            comment: "Coffer Production Release Package v1.0.0"
        )

        let explorerView = ArchiveBrowserView(
            archiveURL: URL(fileURLWithPath: "/Users/developer/Downloads/Coffer_Source_v1.0.0.rar"),
            items: sampleItems,
            metadata: meta,
            currentPath: .constant(""),
            searchText: .constant(""),
            selectedItemIDs: .constant([sampleItems[0].id]),
            onAddFiles: {},
            onExtract: {},
            onTestArchive: {},
            onPreviewItem: { _ in },
            onDeleteSelected: {},
            onCleanMacJunk: {},
            onShowInfo: {},
            onConvertArchive: {},
            onDiffArchive: {},
            onLockArchive: {},
            onRepairArchive: {},
            onNavigateTo: { _ in },
            onNavigateUp: {}
        )

        let framed = MacWindowFrame(
            title: "Coffer — Coffer_Source_v1.0.0.rar (WinRAR Archive)",
            content: { explorerView }
        )

        render(view: framed, size: CGSize(width: 980, height: 620), to: targetPath)
    }

    // MARK: - 2. Ayarlar & Hakkında Penceresi
    private static func generateSettingsScreenshot(targetPath: String) {
        let settingsView = SettingsView(isPresented: .constant(true))
        let framed = MacWindowFrame(
            title: "Coffer — Ayarlar",
            content: { settingsView }
        )
        render(view: framed, size: CGSize(width: 740, height: 580), to: targetPath)
    }

    // MARK: - 3. Canlı Otomatik Güncelleme Penceresi
    private static func generateUpdaterScreenshot(targetPath: String) {
        let release = GitHubReleaseInfo(
            tagName: "v1.0.1",
            version: "1.0.1",
            name: "Coffer v1.0.1 — Performans & İkon Güncellemesi",
            body: """
            ✨ Yenilikler:
            • 60 FPS Retina önbellekleme ve O(1) klasör gezinmesi
            • Apple Liquid Glass biçim simgeleri (RAR, ZIP, 7Z, TAR)
            • Gelişmiş Zip Slip güvenlik kalkanı ve başlık şifreleme denetimi
            • Doğrudan arka planda atomik güncelleme desteği
            """,
            dmgDownloadURL: URL(string: "https://github.com/blackowltr/Coffer/releases/download/v1.0.0/Coffer-1.0.0.dmg"),
            dmgSize: 15_628_490,
            htmlURL: URL(string: "https://github.com/blackowltr/Coffer/releases")!
        )

        UpdateDownloadManager.shared.configure(release: release, currentVersion: "1.0.0", isReinstall: false)
        UpdateDownloadManager.shared.state = .downloading(progress: 0.74, downloaded: 11_565_082, total: 15_628_490)

        let dialog = UpdateDownloadDialog(onDismiss: {})
        let framed = MacWindowFrame(
            title: "Coffer Güncelleme",
            content: { dialog }
        )
        render(view: framed, size: CGSize(width: 480, height: 380), to: targetPath)
    }

    // MARK: - 4. Hızlı Bırakma Penceresi
    private static func generateDropZoneScreenshot(targetPath: String) {
        let dropZone = DropZoneView(
            isHovering: .constant(false),
            onFilesDropped: { _ in },
            onBrowseFiles: {},
            onSwitchToExplorer: {}
        )
        let framed = MacWindowFrame(
            title: "Coffer — Hızlı Mod",
            content: { dropZone }
        )
        render(view: framed, size: CGSize(width: 660, height: 460), to: targetPath)
    }

    // MARK: - Render Motoru (2x Retina 4K PNG)
    private static func render<V: View>(view: V, size: CGSize, to targetPath: String) {
        let scale: CGFloat = 2.0
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }

        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.current = ctx
        ctx.cgContext.scaleBy(x: scale, y: scale)

        hosting.displayIgnoringOpacity(hosting.bounds, in: ctx)
        NSGraphicsContext.restoreGraphicsState()

        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: targetPath))
            print("==> [Retina PNG Kaydedildi] \(targetPath) (\(pngData.count / 1024) KB)")
        }
    }
}

// MARK: - Gerçek macOS Pencere Çerçevesi Sarmalayıcısı
private struct MacWindowFrame<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pencere Başlık Çubuğu & Trafik Işıkları
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 12, height: 12)
                }
                .padding(.leading, 14)

                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))

                Spacer()

                Color.clear.frame(width: 50, height: 12)
            }
            .frame(height: 38)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Divider(), alignment: .bottom
            )

            content
        }
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }
}
