import AppKit
import Foundation

/// macOS Finder Sağ Tık (NSServices / Hızlı Eylemler) Yöneticisi
@objc(CofferServicesProvider)
public final class CofferServicesProvider: NSObject {
    public static let shared = CofferServicesProvider()

    private override init() {
        super.init()
    }

    /// Panodan veya Finder'dan gelen dosya URL'lerini güvenli şekilde ayıklar
    public func extractURLs(from pboard: NSPasteboard) -> [URL] {
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return urls
        }
        let filenamesType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
        if let filenames = pboard.propertyList(forType: filenamesType) as? [String] {
            return filenames.map { URL(fileURLWithPath: $0) }
        }
        return []
    }

    /// Çok parçalı arşiv setlerini (part1...partNN veya .001...NNN) tespit edip ilk ciltten itibaren tek sefer işletir
    public func filterMultiPartSets(urls: [URL]) -> [URL] {
        var processedBaseNames = Set<String>()
        var finalURLs: [URL] = []

        for url in urls {
            let info = MultiPartVolumeManager.shared.analyzeArchive(at: url)
            if info.isMultiPart {
                if !processedBaseNames.contains(info.baseName) {
                    processedBaseNames.insert(info.baseName)
                    if let firstPart = info.allPartURLs.first {
                        finalURLs.append(firstPart)
                    } else {
                        finalURLs.append(url)
                    }
                }
            } else {
                finalURLs.append(url)
            }
        }
        return finalURLs
    }

    // MARK: - 1. Finder Sağ Tık: "Coffer ile Buraya Çıkart"

    @objc public func extractHereService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let rawURLs = extractURLs(from: pboard)
        let urls = filterMultiPartSets(urls: rawURLs)
        guard !urls.isEmpty else { return }

        Task {
            for archiveURL in urls {
                let parentFolder = archiveURL.deletingLastPathComponent()
                do {
                    let (items, _) = try await ArchiveManager.shared.openArchive(at: archiveURL)
                    let (destURL, _) = SmartExtractor.shared.resolveDestinationPath(
                        archiveURL: archiveURL,
                        items: items,
                        baseDestinationURL: parentFolder,
                        enableSmartExtraction: AppSettings.shared.enableSmartExtraction
                    )

                    let stream = await ArchiveManager.shared.extract(archiveURL: archiveURL, destinationURL: destURL)
                    for try await _ in stream {}

                    SmartExtractor.shared.performPostExtractionActions(
                        archiveURL: archiveURL,
                        destinationURL: destURL,
                        trashOriginal: AppSettings.shared.trashArchiveAfterExtract,
                        revealInFinder: true,
                        playSound: AppSettings.shared.playSoundOnCompletion
                    )
                } catch {
                    print("Coffer Buraya Çıkart hatası: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 2. Finder Sağ Tık: "Coffer ile Klasöre Çıkart"

    @objc public func extractToFolderService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let rawURLs = extractURLs(from: pboard)
        let urls = filterMultiPartSets(urls: rawURLs)
        guard !urls.isEmpty else { return }

        Task {
            for archiveURL in urls {
                let folderName = archiveURL.deletingPathExtension().lastPathComponent
                let parentFolder = archiveURL.deletingLastPathComponent()
                let destFolder = parentFolder.appendingPathComponent(folderName, isDirectory: true)

                try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)

                do {
                    let stream = await ArchiveManager.shared.extract(archiveURL: archiveURL, destinationURL: destFolder)
                    for try await _ in stream {}

                    SmartExtractor.shared.performPostExtractionActions(
                        archiveURL: archiveURL,
                        destinationURL: destFolder,
                        trashOriginal: AppSettings.shared.trashArchiveAfterExtract,
                        revealInFinder: true,
                        playSound: AppSettings.shared.playSoundOnCompletion
                    )
                } catch {
                    print("Coffer Klasöre Çıkart hatası: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 3. Finder Sağ Tık: "Coffer ile Belirtilen Yere Çıkart..."

    @objc public func extractToChosenService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let rawURLs = extractURLs(from: pboard)
        let urls = filterMultiPartSets(urls: rawURLs)
        guard !urls.isEmpty else { return }

        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Coffer - Arşivin Çıkartılacağı Konumu Seçin"
            panel.prompt = "Buraya Çıkart"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false

            if panel.runModal() == .OK, let destURL = panel.url {
                Task {
                    for archiveURL in urls {
                        do {
                            let stream = await ArchiveManager.shared.extract(archiveURL: archiveURL, destinationURL: destURL)
                            for try await _ in stream {}

                            SmartExtractor.shared.performPostExtractionActions(
                                archiveURL: archiveURL,
                                destinationURL: destURL,
                                trashOriginal: false,
                                revealInFinder: true,
                                playSound: AppSettings.shared.playSoundOnCompletion
                            )
                        } catch {
                            print("Coffer Belirtilen Yere Çıkart hatası: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 4. Finder Sağ Tık: "Coffer ile Aç ve İncele"

    @objc public func openInCofferService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        guard let first = urls.first else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .cofferFileDropped, object: first)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - 5. Finder Sağ Tık: "Coffer ile Güvenlik & Akıllı Analiz..."

    @objc public func analyzeSecurityService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        guard let first = urls.first else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .cofferFileDropped, object: first)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NotificationCenter.default.post(name: .cofferSecurity, object: nil)
            }
        }
    }

    // MARK: - 6. Finder Sağ Tık: "Coffer ile Hasarlı Arşivi Onar..."

    @objc public func repairArchiveService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        guard let first = urls.first else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .cofferFileDropped, object: first)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NotificationCenter.default.post(name: .cofferRepair, object: nil)
            }
        }
    }

    // MARK: - 7. Finder Sağ Tık: "Coffer ile Arşivle..." (Format, Düzey, Parola Seçim Penceresi)

    @objc public func compressDialogService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        guard !urls.isEmpty else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .cofferCompressFilesWithDialog, object: urls)
        }
    }

    // MARK: - Hızlı Sıkıştırma Metotları (ZIP, RAR, 7Z)

    private func compressFiles(urls: [URL], format: ArchiveFormat) {
        guard !urls.isEmpty else { return }

        Task {
            let parentFolder = urls[0].deletingLastPathComponent()
            let baseName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Arşiv"
            let targetURL = parentFolder.appendingPathComponent("\(baseName).\(format.primaryExtension)")
            let level = AppSettings.shared.defaultCompressionLevelEnum

            do {
                let stream = await ArchiveManager.shared.compress(
                    sourceURLs: urls,
                    destinationURL: targetURL,
                    format: format,
                    level: level,
                    stripMacJunk: AppSettings.shared.stripMacJunkFiles
                )
                for try await _ in stream {}

                NSWorkspace.shared.activateFileViewerSelecting([targetURL])
                if AppSettings.shared.playSoundOnCompletion {
                    NSSound.beep()
                }
            } catch {
                print("Coffer Hızlı Sıkıştırma hatası (\(format.rawValue)): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 8. Finder Sağ Tık: "Coffer ile Hızlı .ZIP Sıkıştır"

    @objc public func compressToZipService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        compressFiles(urls: urls, format: .zip)
    }

    // MARK: - 9. Finder Sağ Tık: "Coffer ile Hızlı .RAR Sıkıştır"

    @objc public func compressToRarService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        compressFiles(urls: urls, format: .rar)
    }

    // MARK: - 10. Finder Sağ Tık: "Coffer ile Hızlı .7Z Sıkıştır"

    @objc public func compressTo7zService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        compressFiles(urls: urls, format: .sevenZip)
    }

    // MARK: - 11. Finder Sağ Tık: "Coffer ile macOS Artıklarını Temizle"

    @objc public func cleanMacJunkService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = extractURLs(from: pboard)
        guard !urls.isEmpty else { return }

        Task {
            var totalCleaned = 0
            for url in urls {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        let cleaned = AppleJunkSanitizer.shared.sanitizeDirectory(at: url)
                        totalCleaned += cleaned
                    } else if ArchiveFormat.detect(from: url) != nil {
                        if let cleaned = try? await AppleJunkSanitizer.shared.cleanArchiveFromMacJunk(archiveURL: url) {
                            totalCleaned += cleaned
                        }
                    } else if AppleJunkSanitizer.shared.isJunk(path: url.path) {
                        try? FileManager.default.removeItem(at: url)
                        totalCleaned += 1
                    }
                }
            }

            await MainActor.run {
                if AppSettings.shared.playSoundOnCompletion {
                    NSSound.beep()
                }
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }
        }
    }

    // MARK: - Finder Servislerini ve Hızlı Eylemleri Yenileme

    @discardableResult
    public func registerFinderServices() -> Bool {
        NSUpdateDynamicServices()
        return true
    }
}

public typealias MacRARServicesProvider = CofferServicesProvider
