import Foundation
import AppKit

/// GitHub Releases üzerinden günlük veya manuel güncelleme denetleyicisi (COFFER_NO_UPDATE_CHECK=1 ile devre dışı bırakılabilir)
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    public let currentVersion = "1.0.0"
    
    /// GitHub kullanıcı adı ve depo adı (GitHub'a deploy ettiğinizde burayı veya UserDefaults'u güncelleyebilirsiniz)
    @Published public var repoSlug: String {
        didSet {
            UserDefaults.standard.set(repoSlug, forKey: "gitHubRepoSlug")
        }
    }
    
    private let lastCheckKey = "lastUpdateCheckTimestamp"

    @Published public var isChecking: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var downloadURL: URL? = nil
    @Published public var lastCheckStatus: String? = nil
    @Published public var lastCheckDate: Date? = nil

    private init() {
        self.repoSlug = UserDefaults.standard.string(forKey: "gitHubRepoSlug") ?? "blackowltr/Coffer"
    }

    private var isCheckDisabled: Bool {
        ProcessInfo.processInfo.environment["COFFER_NO_UPDATE_CHECK"] == "1" ||
        ProcessInfo.processInfo.environment["MACRAR_NO_UPDATE_CHECK"] == "1"
    }

    /// Otomatik günlük kontrol (Uygulama başladığında sessizce çalıştırılır)
    public func performDailyCheckIfDue() {
        if isCheckDisabled {
            return
        }

        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let now = Date().timeIntervalSince1970
        let oneDaySeconds: Double = 86400

        if now - lastCheck >= oneDaySeconds {
            Task {
                await checkForUpdates(manual: false)
            }
        }
    }

    /// Manuel veya otomatik güncelleme denetimi
    public func checkForUpdates(manual: Bool) async {
        if isCheckDisabled && !manual {
            return
        }

        isChecking = true
        defer { isChecking = false }

        guard let apiURL = URL(string: "https://api.github.com/repos/\(repoSlug)/releases/latest") else {
            lastCheckStatus = "Geçersiz GitHub depo adresi."
            return
        }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Coffer-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                if manual {
                    showGitHubPendingAlert()
                }
                lastCheckStatus = "Sunucu yanıt vermedi."
                return
            }

            if http.statusCode == 404 {
                lastCheckStatus = "GitHub altyapısı hazır (Yayın bekleniyor)."
                if manual {
                    showGitHubPendingAlert()
                }
                return
            }

            guard http.statusCode == 200 else {
                lastCheckStatus = "GitHub API yanıt kodu: \(http.statusCode)"
                if manual {
                    showGitHubPendingAlert()
                }
                return
            }

            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
            lastCheckDate = Date()

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String {
                let cleanTag = tagName.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespaces)
                let htmlUrlStr = json["html_url"] as? String ?? "https://github.com/\(repoSlug)/releases"

                if isNewerVersion(cleanTag, than: currentVersion) {
                    latestVersion = cleanTag
                    downloadURL = URL(string: htmlUrlStr)
                    updateAvailable = true
                    lastCheckStatus = "Yeni sürüm v\(cleanTag) mevcut!"
                    showUpdateFoundAlert(newVersion: cleanTag, url: downloadURL)
                } else {
                    lastCheckStatus = "Coffer güncel (v\(currentVersion))."
                    if manual {
                        showUpToDateAlert(
                            title: "Coffer Güncel",
                            message: LocalizationManager.shared.isTurkish
                                ? "Harika! En son Coffer sürümünü (\(currentVersion)) kullanıyorsunuz."
                                : "Coffer is up to date! You are using version \(currentVersion)."
                        )
                    }
                }
            }
        } catch {
            lastCheckStatus = "Bağlantı denetlendi."
            if manual {
                showGitHubPendingAlert()
            }
        }
    }

    private func isNewerVersion(_ newVer: String, than current: String) -> Bool {
        newVer.compare(current, options: .numeric) == .orderedDescending
    }

    private func showUpdateFoundAlert(newVersion: String, url: URL?) {
        let alert = NSAlert()
        let isTR = LocalizationManager.shared.isTurkish
        alert.messageText = isTR ? "Yeni Coffer Sürümü Mevcut!" : "New Coffer Version Available!"
        alert.informativeText = isTR
            ? "Coffer \(newVersion) yayınlandı (Mevcut: \(currentVersion)). İndirmek ister misiniz?"
            : "Coffer \(newVersion) is available (Current: \(currentVersion)). Would you like to download it?"
        alert.addButton(withTitle: isTR ? "İndir ve Güncelle" : "Download Update")
        alert.addButton(withTitle: isTR ? "Daha Sonra" : "Later")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn, let dl = url {
            NSWorkspace.shared.open(dl)
        }
    }

    private func showUpToDateAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: LocalizationManager.shared.isTurkish ? "Tamam" : "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showGitHubPendingAlert() {
        let alert = NSAlert()
        alert.messageText = "GitHub Güncelleme Altyapısı Hazır"
        alert.informativeText = "Coffer otomatik güncelleme altyapısı hazırlandı!\n\nProjenizi GitHub hesabınıza deploy edip Releases kısmından yeni bir sürüm yayınladığınızda, kullanıcılar tek tıkla doğrudan son sürüme erişebilecektir.\n\nHedef Depo: https://github.com/\(repoSlug)"
        alert.addButton(withTitle: "GitHub Deposu")
        alert.addButton(withTitle: "Tamam")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/\(repoSlug)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
