import Cocoa
import FinderSync

/// macOS Finder Sağ Tık Entegrasyonu (Doğrudan Ana Menüde 'Coffer >' Alt Menüsü Sunan FinderSync Uzantısı)
public class FinderSync: FIFinderSync {

    public override init() {
        super.init()

        // Finder'da tüm kullanıcı dizinlerini ve bağlı diskleri izle (Böylece sağ tık her yerde çalışır)
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        FIFinderSyncController.default().directoryURLs = [homeURL, volumesURL, URL(fileURLWithPath: "/")]
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

        // Ana Sağ Tık Menüsünde Doğrudan 'Coffer' Seçeneği
        let cofferItem = NSMenuItem(title: "Coffer", action: nil, keyEquivalent: "")
        cofferItem.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Coffer")

        let subMenu = NSMenu(title: "Coffer")

        let isSingle = targetURLs.count == 1
        let firstURL = targetURLs[0]
        let isArchive = isArchiveFile(firstURL)

        if isArchive && isSingle {
            let archiveName = firstURL.deletingPathExtension().lastPathComponent

            // 1. Coffer ile Buraya Çıkart
            let extractHereItem = NSMenuItem(
                title: "Coffer ile Buraya Çıkart",
                action: #selector(extractHereAction(_:)),
                keyEquivalent: ""
            )
            extractHereItem.target = self
            extractHereItem.image = NSImage(systemSymbolName: "arrow.down.doc.fill", accessibilityDescription: nil)
            subMenu.addItem(extractHereItem)

            // 2. Coffer ile Klasöre Çıkart
            let extractToFolderItem = NSMenuItem(
                title: "Coffer ile Klasöre Çıkart (\"\(archiveName)\")",
                action: #selector(extractToFolderAction(_:)),
                keyEquivalent: ""
            )
            extractToFolderItem.target = self
            extractToFolderItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
            subMenu.addItem(extractToFolderItem)

            // 3. Coffer ile Belirtilen Yere Çıkart...
            let extractToChosenItem = NSMenuItem(
                title: "Coffer ile Belirtilen Yere Çıkart...",
                action: #selector(extractToChosenAction(_:)),
                keyEquivalent: ""
            )
            extractToChosenItem.target = self
            extractToChosenItem.image = NSImage(systemSymbolName: "folder.fill.badge.gearshape", accessibilityDescription: nil)
            subMenu.addItem(extractToChosenItem)

            subMenu.addItem(NSMenuItem.separator())

            // 4. Coffer ile Aç ve İncele
            let openItem = NSMenuItem(
                title: "Coffer ile Aç ve İncele",
                action: #selector(openInCofferAction(_:)),
                keyEquivalent: ""
            )
            openItem.target = self
            openItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
            subMenu.addItem(openItem)

            // 5. Coffer ile Güvenlik & Akıllı Analiz...
            let securityItem = NSMenuItem(
                title: "Coffer ile Güvenlik & Akıllı Analiz...",
                action: #selector(analyzeSecurityAction(_:)),
                keyEquivalent: ""
            )
            securityItem.target = self
            securityItem.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: nil)
            subMenu.addItem(securityItem)

            // 6. Coffer ile Hasarlı Arşivi Onar...
            let repairItem = NSMenuItem(
                title: "Coffer ile Hasarlı Arşivi Onar...",
                action: #selector(repairArchiveAction(_:)),
                keyEquivalent: ""
            )
            repairItem.target = self
            repairItem.image = NSImage(systemSymbolName: "wrench.and.screwdriver.fill", accessibilityDescription: nil)
            subMenu.addItem(repairItem)

            subMenu.addItem(NSMenuItem.separator())

            // 7. Coffer ile macOS Artıklarını Temizle
            let cleanItem = NSMenuItem(
                title: "Coffer ile macOS Artıklarını Temizle",
                action: #selector(cleanMacJunkAction(_:)),
                keyEquivalent: ""
            )
            cleanItem.target = self
            cleanItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            subMenu.addItem(cleanItem)

        } else {
            // Sıkıştırma & Temizlik Seçenekleri

            // 1. Coffer ile Arşivle... (Format, Düzey, Parola)
            let compressDialogItem = NSMenuItem(
                title: "Coffer ile Arşivle... (Format, Düzey, Parola)",
                action: #selector(compressDialogAction(_:)),
                keyEquivalent: ""
            )
            compressDialogItem.target = self
            compressDialogItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
            subMenu.addItem(compressDialogItem)

            subMenu.addItem(NSMenuItem.separator())

            // 2. Coffer ile Hızlı .ZIP Sıkıştır
            let compressZipItem = NSMenuItem(
                title: "Coffer ile Hızlı .ZIP Sıkıştır",
                action: #selector(compressToZipAction(_:)),
                keyEquivalent: ""
            )
            compressZipItem.target = self
            compressZipItem.image = NSImage(systemSymbolName: "doc.zipper", accessibilityDescription: nil)
            subMenu.addItem(compressZipItem)

            // 3. Coffer ile Hızlı .RAR Sıkıştır
            let compressRarItem = NSMenuItem(
                title: "Coffer ile Hızlı .RAR Sıkıştır",
                action: #selector(compressToRarAction(_:)),
                keyEquivalent: ""
            )
            compressRarItem.target = self
            compressRarItem.image = NSImage(systemSymbolName: "archivebox.circle.fill", accessibilityDescription: nil)
            subMenu.addItem(compressRarItem)

            // 4. Coffer ile Hızlı .7Z Sıkıştır
            let compress7zItem = NSMenuItem(
                title: "Coffer ile Hızlı .7Z Sıkıştır",
                action: #selector(compressTo7zAction(_:)),
                keyEquivalent: ""
            )
            compress7zItem.target = self
            compress7zItem.image = NSImage(systemSymbolName: "cube.box.fill", accessibilityDescription: nil)
            subMenu.addItem(compress7zItem)

            subMenu.addItem(NSMenuItem.separator())

            // 5. Coffer ile macOS Artıklarını Temizle (.DS_Store vb.)
            let cleanItem = NSMenuItem(
                title: "Coffer ile macOS Artıklarını Temizle (.DS_Store vb.)",
                action: #selector(cleanMacJunkAction(_:)),
                keyEquivalent: ""
            )
            cleanItem.target = self
            cleanItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            subMenu.addItem(cleanItem)
        }

        cofferItem.submenu = subMenu
        menu.addItem(cofferItem)

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

    private func executeCoffer(arguments: [String]) {
        let pluginURL = Bundle.main.bundleURL
        let appURL = pluginURL.deletingLastPathComponent().deletingLastPathComponent()
        let binaryURL = appURL.appendingPathComponent("MacOS/Coffer")

        if FileManager.default.fileExists(atPath: binaryURL.path) {
            _ = try? Process.run(binaryURL, arguments: arguments)
            return
        }

        // Yedek Uygulama Yolu
        let fallbackURL = URL(fileURLWithPath: "/Applications/Coffer.app/Contents/MacOS/Coffer")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            _ = try? Process.run(fallbackURL, arguments: arguments)
        }
    }

    @objc func extractHereAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--extract-here"] + urls.map { $0.path })
    }

    @objc func extractToFolderAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--extract-to-folder"] + urls.map { $0.path })
    }

    @objc func extractToChosenAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--extract-to-chosen"] + urls.map { $0.path })
    }

    @objc func openInCofferAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard let first = urls.first else { return }
        executeCoffer(arguments: ["--open", first.path])
    }

    @objc func analyzeSecurityAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard let first = urls.first else { return }
        executeCoffer(arguments: ["--analyze", first.path])
    }

    @objc func repairArchiveAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard let first = urls.first else { return }
        executeCoffer(arguments: ["--repair", first.path])
    }

    @objc func compressDialogAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--compress-dialog"] + urls.map { $0.path })
    }

    @objc func compressToZipAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--compress-zip"] + urls.map { $0.path })
    }

    @objc func compressToRarAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--compress-rar"] + urls.map { $0.path })
    }

    @objc func compressTo7zAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--compress-7z"] + urls.map { $0.path })
    }

    @objc func cleanMacJunkAction(_ sender: AnyObject?) {
        let urls = getSelectedURLs()
        guard !urls.isEmpty else { return }
        executeCoffer(arguments: ["--clean-junk"] + urls.map { $0.path })
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
