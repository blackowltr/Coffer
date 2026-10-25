import Cocoa
import FinderSync

/// macOS Finder Sağ Tık Entegrasyonu (Doğrudan Ana Menüde 'UnPack >' Alt Menüsü Sunan FinderSync Uzantısı)
@objc(FinderSync)
public class FinderSync: FIFinderSync {

    public override init() {
        super.init()

        // Finder'da tüm kullanıcı dizinlerini, kök dizini ve bağlı diskleri izle (Sağ tık ana menüde görünür)
        var monitoredURLs = Set<URL>()
        monitoredURLs.insert(URL(fileURLWithPath: "/"))
        monitoredURLs.insert(URL(fileURLWithPath: "/Users"))
        monitoredURLs.insert(URL(fileURLWithPath: "/Volumes"))
        monitoredURLs.insert(FileManager.default.homeDirectoryForCurrentUser)
        FIFinderSyncController.default().directoryURLs = monitoredURLs
    }

    // MARK: - Finder Doğrudan Sağ Tık İçerik Menüsü (Context Menu)

    public override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return nil
        }

        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        let targetURLs = selectedURLs.isEmpty ? [FIFinderSyncController.default().targetedURL()].compactMap { $0 } : selectedURLs
        guard !targetURLs.isEmpty else { return nil }

        let menu = NSMenu(title: "")

        // Ana Sağ Tık Menüsünde Doğrudan 'UnPack' Seçeneği
        let unpackItem = NSMenuItem(title: "UnPack", action: nil, keyEquivalent: "")
        unpackItem.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "UnPack")

        let subMenu = NSMenu(title: "UnPack")

        let isSingle = targetURLs.count == 1
        let firstURL = targetURLs[0]
        let isArchive = isArchiveFile(firstURL)

        if isArchive && isSingle {
            let archiveName = firstURL.deletingPathExtension().lastPathComponent

            // 1. UnPack ile Buraya Çıkart
            let extractHereItem = NSMenuItem(
                title: "UnPack ile Buraya Çıkart",
                action: #selector(extractHereAction(_:)),
                keyEquivalent: ""
            )
            extractHereItem.target = self
            extractHereItem.image = NSImage(systemSymbolName: "arrow.down.doc.fill", accessibilityDescription: nil)
            subMenu.addItem(extractHereItem)

            // 2. UnPack ile Klasöre Çıkart
            let extractToFolderItem = NSMenuItem(
                title: "UnPack ile Klasöre Çıkart (\"\(archiveName)\")",
                action: #selector(extractToFolderAction(_:)),
                keyEquivalent: ""
            )
            extractToFolderItem.target = self
            extractToFolderItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
            subMenu.addItem(extractToFolderItem)

            // 3. UnPack ile Belirtilen Yere Çıkart...
            let extractToChosenItem = NSMenuItem(
                title: "UnPack ile Belirtilen Yere Çıkart...",
                action: #selector(extractToChosenAction(_:)),
                keyEquivalent: ""
            )
            extractToChosenItem.target = self
            extractToChosenItem.image = NSImage(systemSymbolName: "folder.fill.badge.gearshape", accessibilityDescription: nil)
            subMenu.addItem(extractToChosenItem)

            subMenu.addItem(NSMenuItem.separator())

            // 4. UnPack ile Aç ve İncele
            let openItem = NSMenuItem(
                title: "UnPack ile Aç ve İncele",
                action: #selector(openInUnPackAction(_:)),
                keyEquivalent: ""
            )
            openItem.target = self
            openItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
            subMenu.addItem(openItem)

            // 5. UnPack ile Güvenlik Analizi...
            let securityItem = NSMenuItem(
                title: "UnPack ile Güvenlik Analizi...",
                action: #selector(analyzeSecurityAction(_:)),
                keyEquivalent: ""
            )
            securityItem.target = self
            securityItem.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: nil)
            subMenu.addItem(securityItem)

            // 6. UnPack ile Hasarlı Arşivi Onar...
            let repairItem = NSMenuItem(
                title: "UnPack ile Hasarlı Arşivi Onar...",
                action: #selector(repairArchiveAction(_:)),
                keyEquivalent: ""
            )
            repairItem.target = self
            repairItem.image = NSImage(systemSymbolName: "wrench.and.screwdriver.fill", accessibilityDescription: nil)
            subMenu.addItem(repairItem)

            subMenu.addItem(NSMenuItem.separator())

            // 7. UnPack ile macOS Artıklarını Temizle
            let cleanItem = NSMenuItem(
                title: "UnPack ile macOS Artıklarını Temizle",
                action: #selector(cleanMacJunkAction(_:)),
                keyEquivalent: ""
            )
            cleanItem.target = self
            cleanItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            subMenu.addItem(cleanItem)

        } else {
            // Sıkıştırma & Temizlik Seçenekleri

            // 1. UnPack ile Arşivle... (Format, Düzey, Parola)
            let compressDialogItem = NSMenuItem(
                title: "UnPack ile Arşivle... (Format, Düzey, Parola)",
                action: #selector(compressDialogAction(_:)),
                keyEquivalent: ""
            )
            compressDialogItem.target = self
            compressDialogItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
            subMenu.addItem(compressDialogItem)

            subMenu.addItem(NSMenuItem.separator())

            // 2. UnPack ile Hızlı .ZIP Sıkıştır
            let compressZipItem = NSMenuItem(
                title: "UnPack ile Hızlı .ZIP Sıkıştır",
                action: #selector(compressToZipAction(_:)),
                keyEquivalent: ""
            )
            compressZipItem.target = self
            compressZipItem.image = NSImage(systemSymbolName: "doc.zipper", accessibilityDescription: nil)
            subMenu.addItem(compressZipItem)

            // 3. UnPack ile Hızlı .RAR Sıkıştır
            let compressRarItem = NSMenuItem(
                title: "UnPack ile Hızlı .RAR Sıkıştır",
                action: #selector(compressToRarAction(_:)),
                keyEquivalent: ""
            )
            compressRarItem.target = self
            compressRarItem.image = NSImage(systemSymbolName: "archivebox.circle.fill", accessibilityDescription: nil)
            subMenu.addItem(compressRarItem)

            // 4. UnPack ile Hızlı .7Z Sıkıştır
            let compress7zItem = NSMenuItem(
                title: "UnPack ile Hızlı .7Z Sıkıştır",
                action: #selector(compressTo7zAction(_:)),
                keyEquivalent: ""
            )
            compress7zItem.target = self
            compress7zItem.image = NSImage(systemSymbolName: "cube.box.fill", accessibilityDescription: nil)
            subMenu.addItem(compress7zItem)

            subMenu.addItem(NSMenuItem.separator())

            // 5. UnPack ile macOS Artıklarını Temizle (.DS_Store vb.)
            let cleanItem = NSMenuItem(
                title: "UnPack ile macOS Artıklarını Temizle (.DS_Store vb.)",
                action: #selector(cleanMacJunkAction(_:)),
                keyEquivalent: ""
            )
            cleanItem.target = self
            cleanItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            subMenu.addItem(cleanItem)
        }

        unpackItem.submenu = subMenu
        menu.addItem(unpackItem)

        return menu
    }

    // MARK: - Eylemler ve Çalıştırma

    private func getSelectedURLs() -> [URL] {
        let items = FIFinderSyncController.default().selectedItemURLs() ?? []
        if !items.isEmpty { return items }
        if let target = FIFinderSyncController.default().targetedURL() {
            return [target]
        }
        return []
    }

    private func executeUnPack(arguments: [String]) {
        let pluginURL = Bundle.main.bundleURL
        // pluginURL: .../Contents/PlugIns/UnPackFinderSync.appex -> UnPack.app
        let appBundleURL = pluginURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fallbackBundleURL = URL(fileURLWithPath: "/Applications/UnPack.app")
        let targetBundleURL = FileManager.default.fileExists(atPath: appBundleURL.path) ? appBundleURL : fallbackBundleURL

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = arguments
        config.activates = true

        NSWorkspace.shared.openApplication(at: targetBundleURL, configuration: config) { _, error in
            if error != nil {
                // Yedek: Process ile doğrudan ikiliyi çalıştırmayı dene
                let binaryURL = targetBundleURL.appendingPathComponent("Contents/MacOS/UnPack")
                if FileManager.default.fileExists(atPath: binaryURL.path) {
                    _ = try? Process.run(binaryURL, arguments: arguments)
                }
            }
        }
    }

    @objc func extractHereAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--extract-here"] + urls.map { $0.path })
    }

    @objc func extractToFolderAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--extract-to-folder"] + urls.map { $0.path })
    }

    @objc func extractToChosenAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--extract-to-chosen"] + urls.map { $0.path })
    }

    @objc func openInUnPackAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard let first = urls.first else { return }
        executeUnPack(arguments: ["--open", first.path])
    }

    @objc func analyzeSecurityAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard let first = urls.first else { return }
        executeUnPack(arguments: ["--analyze", first.path])
    }

    @objc func repairArchiveAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard let first = urls.first else { return }
        executeUnPack(arguments: ["--repair", first.path])
    }

    @objc func compressDialogAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--compress-dialog"] + urls.map { $0.path })
    }

    @objc func compressToZipAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--compress-zip"] + urls.map { $0.path })
    }

    @objc func compressToRarAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--compress-rar"] + urls.map { $0.path })
    }

    @objc func compressTo7zAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--compress-7z"] + urls.map { $0.path })
    }

    @objc func cleanMacJunkAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeUnPack(arguments: ["--clean-junk"] + urls.map { $0.path })
    }

    private func isArchiveFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        if name.contains(".part") && name.hasSuffix(".rar") { return true }
        if ext == "001" || ext.hasPrefix("z0") { return true }
        let archiveExtensions: Set<String> = [
            "rar", "cbr", "zip", "zipx", "cbz", "7z", "cb7",
            "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst", "iso"
        ]
        return archiveExtensions.contains(ext)
    }
}
