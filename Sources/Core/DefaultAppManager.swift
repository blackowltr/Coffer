import AppKit
import UniformTypeIdentifiers
import CoreServices

/// Coffer'ı macOS Finder'da varsayılan arşiv açıcı olarak kaydeden,
/// Finder Quick Actions (Hızlı Eylemler) kurulumunu yapan ve
/// DMG/Downloads üzerinden çalıştırıldığında Uygulamalar klasörüne taşımayı öneren yönetici.
public final class DefaultAppManager: Sendable {
    public static let shared = DefaultAppManager()

    private init() {}

    /// Desteklenen tüm arşiv uzantılarını Coffer ile ilişkilendirir ve Finder ikonlarını yeniler
    public func registerAsDefaultArchiveHandler(extensions: [String]? = nil) {
        let appURL = Bundle.main.bundleURL
        _ = LSRegisterURL(appURL as CFURL, true)

        let targetExtensions = extensions ?? [
            "rar", "cbr", "rev", "r00", "r01",
            "zip", "zipx", "cbz",
            "7z", "cb7",
            "tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz", "zst",
            "iso", "cab", "wim", "arj", "lzh"
        ]

        for ext in targetExtensions {
            if let utType = UTType(filenameExtension: ext) {
                NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: utType) { error in
                    if let error = error {
                        print("Varsayılan uygulama ayarlama (\(ext)): \(error.localizedDescription)")
                    }
                }
            }
        }

        // DMG uzantısını asla Coffer'a zorlama; macOS'un yerleşik DiskImageMounter uygulamasına bırak/geri yükle
        if let dmgType = UTType(filenameExtension: "dmg") {
            let mounterURL = URL(fileURLWithPath: "/System/Library/CoreServices/DiskImageMounter.app")
            if FileManager.default.fileExists(atPath: mounterURL.path) {
                NSWorkspace.shared.setDefaultApplication(at: mounterURL, toOpen: dmgType) { _ in }
            }
        }

        // QuickLook ve ikon önbelleğini sıfırlama
        let qlProcess = Process()
        qlProcess.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        qlProcess.arguments = ["-r", "cache"]
        try? qlProcess.run()
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
            alert.informativeText = "Coffer'ın Finder sağ tık menüsünün, hızlı eylemlerinin ve dosya ilişkilendirmelerinin sorunsuz çalışabilmesi için uygulamanın Uygulamalar klasöründe bulunması gerekir. Uygulama otomatik olarak Uygulamalar (/Applications) dizinine taşınsın mı?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Uygulamalar'a Taşı")
            alert.addButton(withTitle: "Şimdi Değil")

            if alert.runModal() == .alertFirstButtonReturn {
                let targetURL = URL(fileURLWithPath: "/Applications/Coffer.app")
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
        CofferServicesProvider.shared.registerFinderServices()
        _ = LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }
}
