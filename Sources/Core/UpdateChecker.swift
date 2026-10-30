import Foundation
import AppKit

/// GitHub Releases üzerinden günlük veya manuel güncelleme denetleyicisi (UNPACK_NO_UPDATE_CHECK=1 ile devre dışı bırakılabilir)
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    public let currentVersion = "1.8.5"
    
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
        self.repoSlug = UserDefaults.standard.string(forKey: "gitHubRepoSlug") ?? "blackowltr/UnPack"
    }

    private var isCheckDisabled: Bool {
        ProcessInfo.processInfo.environment["UNPACK_NO_UPDATE_CHECK"] == "1" ||
        ProcessInfo.processInfo.environment["COFFER_NO_UPDATE_CHECK"] == "1" ||
        ProcessInfo.processInfo.environment["MACRAR_NO_UPDATE_CHECK"] == "1"
    }

    /// Arka planda sessiz güncelleme denetimi (UnPack açıkken sessizce denetler, güncelleme varsa pencereyi açar)
    public func performSilentBackgroundCheck() {
        if isCheckDisabled {
            return
        }
        Task {
            await checkForUpdates(manual: false)
        }
    }

    /// Otomatik kontrol (Geriye dönük uyumluluk)
    public func performDailyCheckIfDue() {
        performSilentBackgroundCheck()
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
        request.setValue("UnPack-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
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
                let releaseName = json["name"] as? String ?? "UnPack v\(cleanTag)"
                let releaseBody = json["body"] as? String ?? ""

                var dmgURL: URL? = nil
                var dmgSize: Int64 = 0

                if let assets = json["assets"] as? [[String: Any]] {
                    if let dmgAsset = assets.first(where: { ($0["name"] as? String)?.lowercased().hasSuffix(".dmg") == true }) {
                        if let downloadUrlStr = dmgAsset["browser_download_url"] as? String {
                            dmgURL = URL(string: downloadUrlStr)
                        }
                        dmgSize = (dmgAsset["size"] as? NSNumber)?.int64Value ?? 0
                    }
                }

                let releaseInfo = GitHubReleaseInfo(
                    tagName: tagName,
                    version: cleanTag,
                    name: releaseName,
                    body: releaseBody,
                    dmgDownloadURL: dmgURL,
                    dmgSize: dmgSize,
                    htmlURL: URL(string: htmlUrlStr) ?? URL(string: "https://github.com/\(repoSlug)/releases")!
                )

                let isNewer = isNewerVersion(cleanTag, than: currentVersion)

                if isNewer {
                    latestVersion = cleanTag
                    downloadURL = releaseInfo.dmgDownloadURL ?? releaseInfo.htmlURL
                    updateAvailable = true
                    lastCheckStatus = "Yeni sürüm v\(cleanTag) mevcut!"
                    UpdateDialogManager.shared.show(
                        release: releaseInfo,
                        currentVersion: currentVersion,
                        isReinstall: false
                    )
                } else {
                    lastCheckStatus = "UnPack güncel (v\(currentVersion))."
                    if manual {
                        showUpToDateDialog(release: releaseInfo)
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

    private func showUpToDateDialog(release: GitHubReleaseInfo) {
        let alert = NSAlert()
        alert.messageText = "UnPack Güncel (v\(currentVersion))"
        alert.informativeText = "Harika! Şu anda en son UnPack sürümünü kullanıyorsunuz.\n\nİsterseniz GitHub'da bulunan en son sürümü (v\(release.version)) indirip yeniden kurabilirsiniz."
        alert.addButton(withTitle: "Tamam")
        alert.addButton(withTitle: "Yeniden İndir ve Kur")
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            UpdateDialogManager.shared.show(
                release: release,
                currentVersion: currentVersion,
                isReinstall: true
            )
        }
    }

    private func showGitHubPendingAlert() {
        let alert = NSAlert()
        alert.messageText = "GitHub Güncelleme Altyapısı Hazır"
        alert.informativeText = "UnPack otomatik güncelleme altyapısı hazırlandı!\n\nProjenizi GitHub hesabınıza deploy edip Releases kısmından yeni bir sürüm yayınladığınızda, kullanıcılar tek tıkla doğrudan son sürüme erişebilecektir.\n\nHedef Depo: https://github.com/\(repoSlug)"
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
