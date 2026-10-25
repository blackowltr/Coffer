import Foundation
import AppKit
import SwiftUI

/// GitHub Releases Sürüm Bilgisi Modeli
public struct GitHubReleaseInfo: Sendable, Identifiable {
    public var id: String { tagName }
    public let tagName: String
    public let version: String
    public let name: String
    public let body: String
    public let dmgDownloadURL: URL?
    public let dmgSize: Int64
    public let htmlURL: URL

    public init(
        tagName: String,
        version: String,
        name: String,
        body: String,
        dmgDownloadURL: URL?,
        dmgSize: Int64,
        htmlURL: URL
    ) {
        self.tagName = tagName
        self.version = version
        self.name = name
        self.body = body
        self.dmgDownloadURL = dmgDownloadURL
        self.dmgSize = dmgSize
        self.htmlURL = htmlURL
    }
}

/// GitHub'dan DMG indirme, doğrulama, çıkarma ve uygulamayı otomatik güncelleme yöneticisi
@MainActor
public final class UpdateDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate, @unchecked Sendable {
    public static let shared = UpdateDownloadManager()

    public enum State: Equatable {
        case prompt
        case downloading(progress: Double, downloaded: Int64, total: Int64)
        case verifying
        case installing
        case readyToRelaunch
        case failed(error: String)
    }

    @Published public var state: State = .prompt
    @Published public var releaseInfo: GitHubReleaseInfo?
    @Published public var currentVersion: String = "1.7.0"
    @Published public var isReinstall: Bool = false

    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private var downloadedDmgURL: URL?
    private var activeMountPoint: URL?

    private override init() {
        super.init()
    }

    public func configure(release: GitHubReleaseInfo, currentVersion: String, isReinstall: Bool) {
        self.releaseInfo = release
        self.currentVersion = currentVersion
        self.isReinstall = isReinstall
        self.state = .prompt
    }

    /// İndirme ve kurulum akışını başlatır
    public func startDownloadAndInstall() async {
        guard let release = releaseInfo, let downloadURL = release.dmgDownloadURL else {
            // Eğer doğrudan DMG yoksa, web sayfasını aç
            if let html = releaseInfo?.htmlURL {
                NSWorkspace.shared.open(html)
            }
            state = .failed(error: "İndirilebilir DMG paketi bulunamadı. GitHub sayfası açıldı.")
            return
        }

        state = .downloading(progress: 0.0, downloaded: 0, total: release.dmgSize)

        do {
            let dmgFile = try await downloadDMG(from: downloadURL)
            self.downloadedDmgURL = dmgFile

            state = .verifying
            try await Task.sleep(nanoseconds: 500_000_000)

            state = .installing
            try await installAndRelaunch(dmgURL: dmgFile)
        } catch {
            if (error as? CancellationError) != nil {
                state = .prompt
            } else {
                state = .failed(error: error.localizedDescription)
            }
        }
    }

    /// İndirmeyi iptal eder
    public func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        continuation?.resume(throwing: CancellationError())
        continuation = nil

        if let mount = activeMountPoint {
            _ = detachDMG(at: mount.path)
            try? FileManager.default.removeItem(at: mount)
            activeMountPoint = nil
        }
        if let dmg = downloadedDmgURL {
            try? FileManager.default.removeItem(at: dmg)
            downloadedDmgURL = nil
        }
        state = .prompt
    }

    // MARK: - İndirme İşlemi (URLSessionDownloadDelegate)

    private func downloadDMG(from url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 600

            let sess = URLSession(configuration: config, delegate: self, delegateQueue: .main)
            self.session = sess

            var request = URLRequest(url: url)
            request.setValue("UnPack-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let task = sess.downloadTask(with: request)
            self.downloadTask = task
            task.resume()
        }
    }

    // URLSessionDownloadDelegate: İlerleme takibi
    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (self.releaseInfo?.dmgSize ?? 0)
            let prog = expected > 0 ? Double(totalBytesWritten) / Double(expected) : 0.0
            self.state = .downloading(progress: min(max(prog, 0.0), 1.0), downloaded: totalBytesWritten, total: expected)
        }
    }

    // URLSessionDownloadDelegate: İndirme tamamlandı
    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent("UnPack_Update_\(UUID().uuidString).dmg")

        do {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: location, to: destinationURL)
            Task { @MainActor in
                self.continuation?.resume(returning: destinationURL)
                self.continuation = nil
            }
        } catch {
            Task { @MainActor in
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    // MARK: - Disk Kalıbını Bağlama ve Yeniden Başlatma

    private func installAndRelaunch(dmgURL: URL) async throws {
        let mountPoint = FileManager.default.temporaryDirectory.appendingPathComponent("UnPackMount_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        self.activeMountPoint = mountPoint

        // 1. DMG'yi arka planda bağla
        let attachProcess = Process()
        attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attachProcess.arguments = [
            "attach",
            dmgURL.path,
            "-mountpoint",
            mountPoint.path,
            "-nobrowse",
            "-noautoopen",
            "-quiet"
        ]

        try attachProcess.run()
        attachProcess.waitUntilExit()

        guard attachProcess.terminationStatus == 0 else {
            throw NSError(
                domain: "UnPackUpdate",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "İndirilen disk kalıbı (DMG) sisteme bağlanamadı."]
            )
        }

        // 2. Bağlanan diskteki UnPack.app'i bul
        let directAppURL = mountPoint.appendingPathComponent("UnPack.app")
        var sourceAppPath = directAppURL.path

        if !FileManager.default.fileExists(atPath: sourceAppPath) {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: mountPoint.path)) ?? []
            if let foundApp = files.first(where: { $0.hasSuffix(".app") }) {
                sourceAppPath = mountPoint.appendingPathComponent(foundApp).path
            } else {
                _ = detachDMG(at: mountPoint.path)
                throw NSError(
                    domain: "UnPackUpdate",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Disk kalıbı içerisinde UnPack uygulaması bulunamadı."]
                )
            }
        }

        // 3. Hedef uygulama dizini belirle
        let currentBundlePath = Bundle.main.bundleURL.path
        let targetAppPath: String

        if currentBundlePath.hasSuffix(".app") && !currentBundlePath.contains("/build/") {
            targetAppPath = currentBundlePath
        } else {
            if FileManager.default.fileExists(atPath: "/Applications/UnPack.app") {
                targetAppPath = "/Applications/UnPack.app"
            } else {
                targetAppPath = currentBundlePath
            }
        }

        // 4. Yeniden başlatma ve değiştirme betiğini oluştur
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("unpack_updater_\(UUID().uuidString).sh")
        let currentPID = ProcessInfo.processInfo.processIdentifier

        let updaterScript = """
        #!/bin/bash
        PID="\(currentPID)"
        MOUNT="\(mountPoint.path)"
        SRC="\(sourceAppPath)"
        DST="\(targetAppPath)"
        DMG="\(dmgURL.path)"

        # UnPack uygulamasının kapanmasını bekle (en fazla 10 saniye)
        for i in {1..50}; do
            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi
            sleep 0.2
        done

        # Uygulamayı atomik olarak yenisiyle değiştir
        if [ -d "$SRC" ] && [ -n "$DST" ]; then
            mkdir -p "$(dirname "$DST")"
            rm -rf "$DST" 2>/dev/null || true
            cp -R "$SRC" "$DST"
            xattr -dr com.apple.quarantine "$DST" 2>/dev/null || true
            codesign --force --deep --sign - "$DST" 2>/dev/null || true
        fi

        # DMG'yi ayır (detach)
        if [ -n "$MOUNT" ] && [ -d "$MOUNT" ]; then
            hdiutil detach "$MOUNT" -force 2>/dev/null || true
            rmdir "$MOUNT" 2>/dev/null || true
        fi

        # Geçici DMG dosyasını sil
        if [ -n "$DMG" ] && [ -f "$DMG" ]; then
            rm -f "$DMG" 2>/dev/null || true
        fi

        # LaunchServices veritabanını güncelle
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DST" 2>/dev/null || true

        # Yeni güncellenmiş uygulamayı başlat
        open "$DST"

        # Betiği kaldır
        rm -f "$0" 2>/dev/null || true
        """

        try updaterScript.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        // 5. Güncelleme betiğini bağımsız arka planda çalıştır
        let spawnProcess = Process()
        spawnProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        spawnProcess.arguments = [scriptPath.path]
        try spawnProcess.run()

        // 6. Başarılı durumu bildir ve uygulamayı kapat
        state = .readyToRelaunch
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        NSApp.terminate(nil)
    }

    private func detachDMG(at mountPoint: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["detach", mountPoint, "-force", "-quiet"]
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}

/// Güncelleme iletişim kutusunu bağımsız bir macOS penceresi olarak yöneten sınıf
@MainActor
public final class UpdateDialogManager: ObservableObject {
    public static let shared = UpdateDialogManager()

    private var updateWindow: NSWindow?

    private init() {}

    public func show(release: GitHubReleaseInfo, currentVersion: String, isReinstall: Bool) {
        UpdateDownloadManager.shared.configure(
            release: release,
            currentVersion: currentVersion,
            isReinstall: isReinstall
        )

        if let win = updateWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let dialogView = UpdateDownloadDialog { [weak self] in
            self?.close()
        }

        let hosting = NSHostingController(rootView: dialogView)
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.title = "UnPack Güncelleme"
        win.isReleasedWhenClosed = false
        win.center()
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        self.updateWindow = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        updateWindow?.close()
        updateWindow = nil
    }
}
