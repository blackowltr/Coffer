import AppKit
import UniformTypeIdentifiers
import CoreServices

/// UnPack'i macOS Finder'da varsayılan arşiv açıcı olarak kaydeden,
/// Finder Quick Actions (Hızlı Eylemler) kurulumunu yapan ve
/// DMG/Downloads üzerinden çalıştırıldığında Uygulamalar klasörüne taşımayı öneren yönetici.
public final class DefaultAppManager: Sendable {
    public static let shared = DefaultAppManager()

    private init() {}

    /// Desteklenen tüm arşiv uzantılarını UnPack ile ilişkilendirir ve Finder ikonlarını yeniler.
    /// LaunchServices API kullanılarak tüm uzantılar tek seferde, kullanıcıya tek tek sormadan toplu kaydedilir.
    public func registerAsDefaultArchiveHandler(extensions: [String]? = nil) {
        let appURL = Bundle.main.bundleURL
        let bundleID = (Bundle.main.bundleIdentifier ?? "com.unpack.app") as CFString
        _ = LSRegisterURL(appURL as CFURL, true)

        let knownUTIs: [String] = [
            "com.rarlab.rar-archive",
            "public.rar",
            "com.unpack.rar",
            "public.zip-archive",
            "com.pkware.zip-archive",
            "org.7-zip.7-zip-archive",
            "public.tar-archive",
            "public.tar-bzip2-archive",
            "org.gnu.gnu-zip-archive",
            "org.gnu.gnu-zip-tar-archive",
            "public.bzip2-archive",
            "org.tukaani.xz-archive",
            "org.tukaani.tar-xz-archive",
            "public.iso-image",
            "public.archive"
        ]

        for uti in knownUTIs {
            _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, bundleID)
        }

        let targetExtensions = extensions ?? [
            "rar", "cbr", "rev", "r00", "r01",
            "zip", "zipx", "cbz",
            "7z", "cb7",
            "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst",
            "iso", "cab", "wim", "arj", "lzh"
        ]

        for ext in targetExtensions {
            if let utType = UTType(filenameExtension: ext) {
                _ = LSSetDefaultRoleHandlerForContentType(utType.identifier as CFString, .all, bundleID)
            }
        }

        // DMG uzantısını asla UnPack'e zorlama; macOS'un yerleşik DiskImageMounter uygulamasına bırak
        if let dmgType = UTType(filenameExtension: "dmg") {
            let mounterBundleID = "com.apple.DiskImageMounter" as CFString
            _ = LSSetDefaultRoleHandlerForContentType(dmgType.identifier as CFString, .all, mounterBundleID)
        }

        // QuickLook ve ikon önbelleğini arka planda sıfırlama (ana iş parçacığını bloke etmez)
        DispatchQueue.global(qos: .utility).async {
            let qlProcess = Process()
            qlProcess.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            qlProcess.arguments = ["-r", "cache"]
            try? qlProcess.run()
            qlProcess.waitUntilExit()
        }
    }

    /// İlk kurulumda veya doğrudan açılışta kullanıcıya TEK SEFER sorarak tüm arşiv formatlarını topluca UnPack ile açmayı teklif eder.
    public func promptToSetDefaultArchiveHandlerIfNeeded() {
        let hasPromptedKey = "hasPromptedForDefaultArchiveHandler"
        if UserDefaults.standard.bool(forKey: hasPromptedKey) {
            return
        }

        // İlk kurulum sihirbazı henüz tamamlanmadıysa çakışmayı önlemek için ertele
        if !AppSettings.shared.hasCompletedOnboarding && !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if UserDefaults.standard.bool(forKey: hasPromptedKey) { return }

            let alert = NSAlert()
            alert.messageText = "Saptanmış Arşiv Yöneticisi Yapılsın mı?"
            alert.informativeText = "UnPack'in tüm arşiv formatlarını (.zip, .rar, .7z, .tar, .gz, .xz vb.) tek dokunuşla açabilmesi için saptanmış arşiv uygulaması olarak ayarlanmasını ister misiniz?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Tümünü UnPack ile Aç")
            alert.addButton(withTitle: "Daha Sonra")

            let response = alert.runModal()
            UserDefaults.standard.set(true, forKey: hasPromptedKey)

            if response == .alertFirstButtonReturn {
                self.registerAsDefaultArchiveHandler()
            }
        }
    }

    /// DMG veya İndirilenler klasöründen çalışıyorsa Uygulamalar klasörüne taşımayı teklif eder
    public func offerMoveToApplicationsIfNeeded() {
        if AppSettings.shared.hasCompletedOnboarding || UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            return
        }

        let bundleURL = Bundle.main.bundleURL
        let path = bundleURL.path

        // Eğer zaten /Applications veya ~/Applications içindeyse bir şey yapma
        if path.hasPrefix("/Applications/") || path.contains("/Users/") && path.contains("/Applications/") {
            return
        }

        // /Volumes/ (DMG) veya Downloads klasöründeyse kullanıcıya sor
        let isDMG = path.hasPrefix("/Volumes/")
        let isDownloads = path.contains("/Downloads/")

        guard isDMG || isDownloads else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let alert = NSAlert()
            alert.messageText = "Uygulamalar Klasörüne Taşı"
            alert.informativeText = "UnPack'in Finder sağ tık menüsünün, hızlı eylemlerinin ve dosya ilişkilendirmelerinin sorunsuz çalışabilmesi için uygulamanın Uygulamalar klasöründe bulunması gerekir. Uygulama otomatik olarak Uygulamalar (/Applications) dizinine taşınsın mı?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Uygulamalar'a Taşı")
            alert.addButton(withTitle: "Şimdi Değil")

            if alert.runModal() == .alertFirstButtonReturn {
                let targetURL = URL(fileURLWithPath: "/Applications/UnPack.app")
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: bundleURL, to: targetURL)

                    // Yeni konumdan başlat ve mevcut olanı kapat
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, _ in
                        NSApp.terminate(nil)
                    }
                } catch {
                    let errAlert = NSAlert(error: error)
                    errAlert.runModal()
                }
            }
        }
    }

    /// Finder Quick Actions (Hızlı Eylemler) kurulumunu gerçekleştirir veya onarır
    public func installQuickActions() {
        UnPackServicesProvider.shared.registerFinderServices()
        _ = LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }
}
