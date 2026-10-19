import SwiftUI
import AppKit

@main
struct CofferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // App Menu Ekleri (Check for Updates, File Associations, Quick Actions, RAR Tool)
            CommandGroup(after: .appInfo) {
                Button("menu.checkUpdates".loc) {
                    Task {
                        await UpdateChecker.shared.checkForUpdates(manual: true)
                    }
                }

                Button("menu.fileAssociations".loc) {
                    DefaultAppManager.shared.registerAsDefaultArchiveHandler()
                    let alert = NSAlert()
                    alert.messageText = "Dosya İlişkilendirmeleri Güncellendi"
                    alert.informativeText = "Coffer; desteklenen tüm arşiv türleri (.rar, .zip, .7z, .tar, .gz, .xz, .bz2 vb.) için saptanmış arşiv uygulaması olarak ayarlandı."
                    alert.runModal()
                }

                Button("menu.reinstallQuickActions".loc) {
                    DefaultAppManager.shared.installQuickActions()
                    let alert = NSAlert()
                    alert.messageText = "Finder Hızlı Eylemleri Onarıldı"
                    alert.informativeText = "Finder sağ tık menü komutları ve servisleri başarıyla yeniden kaydedildi."
                    alert.runModal()
                }

                Button("menu.installRarTool".loc) {
                    if let url = URL(string: "https://www.rarlab.com/download.htm") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()
            }

            // Dosya Menüsü (Yeni, Aç, Son Kullanılanlar)
            CommandGroup(replacing: .newItem) {
                Button("menu.newArchive".loc) {
                    NotificationCenter.default.post(name: .cofferNewArchive, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("menu.openArchive".loc) {
                    NotificationCenter.default.post(name: .cofferOpenArchive, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu("menu.openRecent".loc) {
                    let recents = NSDocumentController.shared.recentDocumentURLs
                    if recents.isEmpty {
                        Text("Son Kullanılan Arşiv Yok")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recents.prefix(10), id: \.self) { url in
                            Button(url.lastPathComponent) {
                                NotificationCenter.default.post(name: .cofferFileDropped, object: url)
                            }
                        }
                        Divider()
                        Button("menu.clearRecent".loc) {
                            NSDocumentController.shared.clearRecentDocuments(nil)
                        }
                    }
                }
            }

            // Görüntü Menüsü (Genişlet, Daralt, Yenile, Finder'da Göster)
            CommandMenu("menu.view".loc) {
                Button("menu.expandAll".loc) {
                    NotificationCenter.default.post(name: .cofferExpandAll, object: nil)
                }

                Button("menu.collapseAll".loc) {
                    NotificationCenter.default.post(name: .cofferCollapseAll, object: nil)
                }

                Divider()

                Button("menu.refresh".loc) {
                    NotificationCenter.default.post(name: .cofferRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("menu.showInFinder".loc) {
                    NotificationCenter.default.post(name: .cofferShowInFinder, object: nil)
                }
            }

            // Arşiv İşlemleri Menüsü (Çıkar, Ekle, Sil, Test, Onar)
            CommandMenu("menu.archive".loc) {
                Button("menu.extractHere".loc) {
                    NotificationCenter.default.post(name: .cofferExtractHere, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("menu.extractToFolder".loc) {
                    NotificationCenter.default.post(name: .cofferExtractToFolder, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .option])

                Button("menu.extractToChosen".loc) {
                    NotificationCenter.default.post(name: .cofferExtractToChosen, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("menu.extractSelected".loc) {
                    NotificationCenter.default.post(name: .cofferExtractSelected, object: nil)
                }

                Divider()

                Button("menu.addFiles".loc) {
                    NotificationCenter.default.post(name: .cofferAddFiles, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Button("menu.deleteSelected".loc) {
                    NotificationCenter.default.post(name: .cofferDeleteSelected, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Divider()

                Button("menu.testArchive".loc) {
                    NotificationCenter.default.post(name: .cofferTest, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("menu.archiveInfo".loc) {
                    NotificationCenter.default.post(name: .cofferInfo, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Divider()

                Button("Güvenlik ve Risk Analizi...") {
                    NotificationCenter.default.post(name: .cofferSecurity, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("menu.repairArchive".loc) {
                    NotificationCenter.default.post(name: .cofferRepair, object: nil)
                }
            }

            // Yardım Menüsü
            CommandGroup(replacing: .help) {
                Button("Coffer Yardım ve Kısayollar") {
                    if let url = URL(string: "https://github.com/blackowltr/Coffer") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Kurulum ve İzin Sihirbazı...") {
                    NotificationCenter.default.post(name: .cofferShowOnboarding, object: nil)
                }
            }
        }

        // macOS Standart Ayarlar Penceresi (Cmd+,)
        Settings {
            SettingsView(isPresented: .constant(true))
        }

        // macOS Menü Çubuğu (Menu Bar) Widget'ı
        MenuBarExtra("Coffer", systemImage: "archivebox.fill") {
            MenuBarDropZoneView(
                onFileDropped: { url in
                    NotificationCenter.default.post(name: .cofferFileDropped, object: url)
                    NSApp.activate(ignoringOtherApps: true)
                },
                onOpenMainWindow: {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                },
                onOpenArchivePicker: {
                    NotificationCenter.default.post(name: .cofferOpenArchive, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                },
                onBrowseCompress: {
                    NotificationCenter.default.post(name: .cofferNewArchive, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            )
        }
        .menuBarExtraStyle(.window)
    }
}

// Notifications are defined in Core/NotificationNames.swift

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = CofferServicesProvider.shared
        NSUpdateDynamicServices()

        // macOS LaunchServices ve dosya ikonlarını Coffer logosuyla eşitle
        DefaultAppManager.shared.registerAsDefaultArchiveHandler()

        // DMG veya Downloads'tan açılmışsa Uygulamalar klasörüne taşımayı öner
        DefaultAppManager.shared.offerMoveToApplicationsIfNeeded()

        // Otomatik günlük güncelleme kontrolünü başlat
        UpdateChecker.shared.performDailyCheckIfDue()

        handleCommandLineArguments()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let firstURL = urls.first else { return }
        NSDocumentController.shared.noteNewRecentDocumentURL(firstURL)
        NotificationCenter.default.post(name: .cofferFileDropped, object: firstURL)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func handleCommandLineArguments() {
        let args = CommandLine.arguments
        guard args.count >= 2 else { return }

        // Durum 1: Doğrudan dosya açma (Örnek: Coffer /path/to/archive.zip)
        if args.count == 2 && !args[1].hasPrefix("--") {
            let fileURL = URL(fileURLWithPath: args[1])
            NotificationCenter.default.post(name: .cofferFileDropped, object: fileURL)
            return
        }

        guard args.count >= 3 else { return }
        let flag = args[1]
        let filePaths = Array(args.dropFirst(2))
        let urls = filePaths.map { URL(fileURLWithPath: $0) }

        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.writeObjects(urls as [NSURL])
        var err: NSString?

        switch flag {
        case "--extract-here":
            CofferServicesProvider.shared.extractHereService(pboard, userData: "", error: &err)
        case "--extract-to-folder":
            CofferServicesProvider.shared.extractToFolderService(pboard, userData: "", error: &err)
        case "--extract-to-chosen":
            CofferServicesProvider.shared.extractToChosenService(pboard, userData: "", error: &err)
        case "--open":
            CofferServicesProvider.shared.openInCofferService(pboard, userData: "", error: &err)
        case "--analyze", "--security":
            CofferServicesProvider.shared.analyzeSecurityService(pboard, userData: "", error: &err)
        case "--repair":
            CofferServicesProvider.shared.repairArchiveService(pboard, userData: "", error: &err)
        case "--compress-dialog":
            CofferServicesProvider.shared.compressDialogService(pboard, userData: "", error: &err)
        case "--compress-zip":
            CofferServicesProvider.shared.compressToZipService(pboard, userData: "", error: &err)
        case "--compress-rar":
            CofferServicesProvider.shared.compressToRarService(pboard, userData: "", error: &err)
        case "--compress-7z":
            CofferServicesProvider.shared.compressTo7zService(pboard, userData: "", error: &err)
        case "--clean-junk":
            CofferServicesProvider.shared.cleanMacJunkService(pboard, userData: "", error: &err)
        default:
            break
        }
    }
}
