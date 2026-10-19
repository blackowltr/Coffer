import Foundation
import AppKit
import Quartz

/// Arşiv içerisindeki dosyaları çıkarmadan yerel macOS Quick Look (Boşluk Tuşu) penceresiyle önizleyen yönetici
@MainActor
public final class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookHelper()

    private var currentPreviewURL: URL?

    private override init() {
        super.init()
    }

    /// Verilen yerel dosya URL'sini yerel macOS Quick Look (QLPreviewPanel) penceresiyle anında açar
    public func previewFile(at url: URL) {
        self.currentPreviewURL = url

        guard let panel = QLPreviewPanel.shared() else {
            NSWorkspace.shared.open(url)
            return
        }

        panel.dataSource = self
        panel.delegate = self
        panel.updateController()
        panel.reloadData()

        if !panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Dosyayı Finder'da seçili gösterir
    public func revealInFinder(at url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    // MARK: - QLPreviewPanelDataSource

    nonisolated public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            return currentPreviewURL != nil ? 1 : 0
        }
    }

    nonisolated public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated {
            return (currentPreviewURL as NSURL?)
        }
    }

    // MARK: - QLPreviewPanelDelegate

    nonisolated public func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        if event.type == .keyDown && event.keyCode == 49 { // Spacebar
            DispatchQueue.main.async {
                panel.orderOut(nil)
            }
            return true
        }
        return false
    }
}
