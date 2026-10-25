import Foundation
import CryptoKit

// MARK: - Güvenlik Seviyeleri ve Modelleri

public enum SecurityRiskLevel: String, Codable, Sendable {
    case safe = "Güvenli"
    case warning = "Dikkat Gerektirir"
    case danger = "Yüksek / Kritik Risk"

    public var colorName: String {
        switch self {
        case .safe: return "green"
        case .warning: return "orange"
        case .danger: return "red"
        }
    }

    public var systemIcon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        case .danger: return "xmark.shield.fill"
        }
    }
}

public enum FindingSeverity: String, Codable, Sendable, Comparable {
    case info = "Bilgi"
    case low = "Düşük"
    case medium = "Orta"
    case high = "Yüksek"
    case critical = "Kritik"

    private var rank: Int {
        switch self {
        case .info: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    public static func < (lhs: FindingSeverity, rhs: FindingSeverity) -> Bool {
        return lhs.rank < rhs.rank
    }
}

public enum FindingCategory: String, Codable, Sendable {
    case zipBomb = "Sıkıştırma Bombası (Zip Bomb)"
    case pathTraversal = "Dizin Aşımı (Zip Slip / Traversal)"
    case executableOrScript = "Yürütülebilir Dosya / Betik"
    case disguisedApp = "Gizlenmiş / Çift Uzantılı Uygulama"
    case quarantineOrigin = "İnternet Kaynaklı Karantina"
    case hiddenSuspicious = "Gizli / Şüpheli Sistem Dosyası"
    case excessiveFileCount = "Aşırı Dosya Sayısı"
}

public struct SecurityFinding: Identifiable, Sendable {
    public let id: UUID
    public let severity: FindingSeverity
    public let category: FindingCategory
    public let title: String
    public let details: String
    public let affectedPaths: [String]
    public let recommendation: String

    public init(
        id: UUID = UUID(),
        severity: FindingSeverity,
        category: FindingCategory,
        title: String,
        details: String,
        affectedPaths: [String] = [],
        recommendation: String
    ) {
        self.id = id
        self.severity = severity
        self.category = category
        self.title = title
        self.details = details
        self.affectedPaths = affectedPaths
        self.recommendation = recommendation
    }
}

public struct ArchiveSecurityReport: Sendable {
    public let archiveURL: URL
    public let riskLevel: SecurityRiskLevel
    public let safetyScore: Int // 0..100
    public let findings: [SecurityFinding]
    public let totalItems: Int
    public let totalUncompressedSize: Int64
    public let totalCompressedSize: Int64
    public let compressionRatio: Double
    public let executableCount: Int
    public let scriptCount: Int
    public let hiddenCount: Int
    public let hasQuarantineFlag: Bool
    public let quarantineOriginAgent: String?
    public var sha256Checksum: String?
    public var md5Checksum: String?

    public var hasCriticalRisk: Bool {
        return riskLevel == .danger || findings.contains { $0.severity == .critical }
    }
}

// MARK: - Arşiv Güvenlik ve Tehdit Analiz Motoru

public final class ArchiveSecurityEngine: Sendable {
    public static let shared = ArchiveSecurityEngine()

    private init() {}

    // MARK: - Bilinen Tehlikeli Uzantı Kümeleri

    private static let dangerousExecutableExtensions: Set<String> = [
        "exe", "msi", "bat", "cmd", "com", "scr", "vbs", "ps1", "pif",
        "application", "gadget", "hta", "cpl", "msc", "jar", "dylib", "so"
    ]

    private static let scriptExtensions: Set<String> = [
        "sh", "command", "bash", "zsh", "py", "rb", "pl", "scpt",
        "applescript", "php", "tool"
    ]

    private static let harmlessDocumentExtensions: Set<String> = [
        "pdf", "docx", "doc", "xlsx", "xls", "pptx", "ppt", "txt", "rtf",
        "jpg", "jpeg", "png", "gif", "heic", "webp", "mp4", "mov", "mp3", "wav"
    ]

    // MARK: - Arşivi Kapsamlı Güvenlik Taramasından Geçir

    public func analyze(archiveURL: URL, items: [ArchiveItem]) -> ArchiveSecurityReport {
        var findings: [SecurityFinding] = []
        var score: Int = 100

        let totalUncompressed = items.reduce(0) { $0 + $1.uncompressedSize }
        let totalCompressed = (try? archiveURL.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init)) ??
                              items.reduce(0) { $0 + $1.compressedSize }

        let effectiveCompressed = max(1, totalCompressed)
        let ratio = Double(totalUncompressed) / Double(effectiveCompressed)

        // 1. Sıkıştırma Bombası (Zip Bomb / Disk Exhaustion) Analizi
        if ratio > 100.0 && totalUncompressed > 1_073_741_824 { // 1 GB ve 100 kat
            score -= 60
            findings.append(SecurityFinding(
                severity: .critical,
                category: .zipBomb,
                title: "Kritik Sıkıştırma Bombası (Zip Bomb) Tehdidi",
                details: String(format: "Arşivin sıkıştırma oranı 1:%.1f katına ulaşıyor. Dosyalar çıkarıldığında diskinizde %@ yer kaplayacak. Bu durum disk alanını tüketip sistemi kilitleyebilir.", ratio, ByteCountFormatter.string(fromByteCount: totalUncompressed, countStyle: .file)),
                recommendation: "Bu arşivi doğrudan çıkartmayın. Yalnızca güvendiğiniz kaynaklardan gelen arşivleri kabul edin."
            ))
        } else if ratio > 40.0 && totalUncompressed > 5_368_709_120 { // 5 GB ve 40 kat
            score -= 35
            findings.append(SecurityFinding(
                severity: .high,
                category: .zipBomb,
                title: "Olağan Dışı Yüksek Sıkıştırma Oranı",
                details: String(format: "Arşiv boyutu çok küçük olmasına rağmen (yaklaşık 1:%.1f kat) çıkarıldığında %@ alana genişleyecektir.", ratio, ByteCountFormatter.string(fromByteCount: totalUncompressed, countStyle: .file)),
                recommendation: "Yeterli disk alanınız olduğundan emin olun."
            ))
        } else if totalCompressed < 20_971_520 && totalUncompressed > 21_474_836_480 { // 20 MB altı arşiv 20 GB iddia ediyor
            score -= 55
            findings.append(SecurityFinding(
                severity: .critical,
                category: .zipBomb,
                title: "Şüpheli Boyut Genişlemesi",
                details: "20 MB'tan küçük bir arşiv paketi 20 GB'tan fazla veri içerdiğini bildiriyor.",
                recommendation: "Zip bomb olma olasılığı çok yüksektir. Çıkarmadan önce içeriği tekil olarak inceleyin."
            ))
        }

        // Dosya Sayısı Patlaması Kontrolü
        if items.count > 50_000 && totalCompressed < 15_000_000 {
            score -= 30
            findings.append(SecurityFinding(
                severity: .high,
                category: .excessiveFileCount,
                title: "Aşırı Dosya Sayısı (Dosya Sistemi Boğma)",
                details: "\(items.count) adet küçük dosya tespit edildi. Çıkarma sırasında macOS dosya sistemini yavaşlatabilir.",
                recommendation: "Klasör bazında seçerek ayıklamayı tercih edin."
            ))
        }

        // 2. Dizin Aşımı (Zip Slip / Path Traversal) Analizi
        var traversalPaths: [String] = []
        for item in items {
            let path = item.path
            let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
            // Gerçek Zip Slip dizin aşımı: "../", "..\" gibi çıkarma klasörünün dışına sıçramaya çalışan yollar
            if path.contains("../") || path.contains("..\\") || clean == ".." || clean.hasPrefix("../") || clean.hasPrefix("..\\") {
                traversalPaths.append(path)
            } else if path.hasPrefix("/etc/") || path.hasPrefix("/var/") || path.hasPrefix("/System/") || path.contains("/.ssh/") || path.hasPrefix(".ssh/") {
                traversalPaths.append(path)
            }
        }

        if !traversalPaths.isEmpty {
            score -= 75
            findings.append(SecurityFinding(
                severity: .critical,
                category: .pathTraversal,
                title: "Kritik Dizin Aşımı (Zip Slip Açığı)",
                details: "\(traversalPaths.count) adet dosya, çıkarma dizininin dışına çıkarak sistem dosyalarına veya kullanıcı ana dizinine erişmeye çalışıyor.",
                affectedPaths: Array(traversalPaths.prefix(10)),
                recommendation: "Bu arşivi kesinlikle standart çıkarmayın! UnPack Güvenli Çıkarma modunu kullanarak yolları temizleyin."
            ))
        }

        // 3. Yürütülebilir Dosyalar, Sahte / Çift Uzantılı Dosyalar
        var dangerousExecutables: [String] = []
        var scripts: [String] = []
        var disguisedApps: [String] = []
        var hiddenSuspiciousFiles: [String] = []

        let deceptiveExecs: Set<String> = ["exe", "scr", "vbs", "bat", "cmd", "pif", "hta"]

        for item in items {
            guard !item.isDirectory else { continue }
            let ext = item.fileExtension

            // Gerçek çift uzantılı kimlik avı kontrolü: örn "fatura.pdf.exe", "resim.jpg.scr"
            // Yalnızca aldatıcı bir uzantı varsa ayrıştırma yapılır (Gereksiz dizi tahsisatı önlenir)
            if deceptiveExecs.contains(ext) {
                let parts = item.lowerName.split(separator: ".")
                if parts.count >= 3 {
                    let penultimateExt = String(parts[parts.count - 2])
                    if Self.harmlessDocumentExtensions.contains(penultimateExt) {
                        disguisedApps.append(item.path)
                    }
                }
            }

            if Self.dangerousExecutableExtensions.contains(ext) {
                dangerousExecutables.append(item.path)
            } else if Self.scriptExtensions.contains(ext) {
                scripts.append(item.path)
            }

            // Gizlenmiş yürütülebilir dosyalar (örn: .gizli.exe)
            if item.name.hasPrefix(".") && Self.dangerousExecutableExtensions.contains(ext) {
                hiddenSuspiciousFiles.append(item.path)
            }
        }

        if !disguisedApps.isEmpty {
            score -= 50
            findings.append(SecurityFinding(
                severity: .critical,
                category: .disguisedApp,
                title: "Gizlenmiş / Çift Uzantılı Sahte Dosya Tespit Edildi",
                details: "\(disguisedApps.count) adet dosya, zararsız bir belge (PDF, Resim, Word) gibi görünüp arka planda çalıştırılabilir kod içermektedir.",
                affectedPaths: Array(disguisedApps.prefix(8)),
                recommendation: "Bu dosyaları doğrudan açmayın. Genellikle kimlik avı (phishing) veya kötü amaçlı yazılımlarda kullanılır."
            ))
        }

        if !dangerousExecutables.isEmpty {
            score -= min(15, dangerousExecutables.count * 3)
            findings.append(SecurityFinding(
                severity: .low,
                category: .executableOrScript,
                title: "Yürütülebilir / İkili Dosyalar Mevcut",
                details: "Arşiv içinde \(dangerousExecutables.count) adet sistem çalıştırılabilir dosyası (.exe, .dylib vb.) bulundu.",
                affectedPaths: Array(dangerousExecutables.prefix(6)),
                recommendation: "Yalnızca güvendiğiniz kaynaklardan gelen ikili dosyaları çalıştırın."
            ))
        }

        if !scripts.isEmpty {
            score -= min(10, scripts.count * 2)
            findings.append(SecurityFinding(
                severity: .info,
                category: .executableOrScript,
                title: "Betik Dosyaları (Scriptler) Bulundu",
                details: "Arşiv içinde \(scripts.count) adet komut satırı betiği (.sh, .py vb.) mevcut.",
                affectedPaths: Array(scripts.prefix(6)),
                recommendation: "Geliştirici veya sistem betikleri içerir."
            ))
        }

        if !hiddenSuspiciousFiles.isEmpty {
            score -= 5
            findings.append(SecurityFinding(
                severity: .low,
                category: .hiddenSuspicious,
                title: "Nokta ile Başlayan Gizli Dosyalar",
                details: "Arşiv içinde sistem veya konfigürasyon dosyaları (.env vb.) tespit edildi.",
                affectedPaths: Array(hiddenSuspiciousFiles.prefix(6)),
                recommendation: "Gizli dosyaları ayıklarken dikkatli olun."
            ))
        }

        // 4. macOS Karantina (com.apple.quarantine) Özniteliği Kontrolü
        let (hasQuarantine, agent) = inspectQuarantineAttribute(for: archiveURL)
        if hasQuarantine {
            findings.append(SecurityFinding(
                severity: .info,
                category: .quarantineOrigin,
                title: "İnternet Üzerinden İndirildi (Gatekeeper Karantinası)",
                details: "Bu arşiv dosyası internet üzerinden indirilmiş (\(agent ?? "Web Tarayıcısı / İstemci")). macOS Gatekeeper koruması altındadır.",
                recommendation: "İçerikleri açarken macOS güvenlik uyarılarını dikkate alın."
            ))
        }

        // Güvenlik Skoru ve Nihai Seviye Belirleme
        score = max(0, min(100, score))
        let riskLevel: SecurityRiskLevel
        if score >= 70 && !findings.contains(where: { $0.severity == .critical }) {
            riskLevel = .safe
        } else if score >= 40 && !findings.contains(where: { $0.severity == .critical }) {
            riskLevel = .warning
        } else {
            riskLevel = .danger
        }

        return ArchiveSecurityReport(
            archiveURL: archiveURL,
            riskLevel: riskLevel,
            safetyScore: score,
            findings: findings,
            totalItems: items.count,
            totalUncompressedSize: totalUncompressed,
            totalCompressedSize: totalCompressed,
            compressionRatio: ratio,
            executableCount: dangerousExecutables.count,
            scriptCount: scripts.count,
            hiddenCount: hiddenSuspiciousFiles.count,
            hasQuarantineFlag: hasQuarantine,
            quarantineOriginAgent: agent,
            sha256Checksum: nil,
            md5Checksum: nil
        )
    }

    // MARK: - Karantina Özniteliğini İnceleme

    private func inspectQuarantineAttribute(for url: URL) -> (hasQuarantine: Bool, agent: String?) {
        let path = url.path
        let bufferSize = 1024
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let result = getxattr(path, "com.apple.quarantine", &buffer, bufferSize, 0, 0)
        guard result > 0 else { return (false, nil) }

        let quarantineString = String(cString: buffer)
        let parts = quarantineString.split(separator: ";")
        let agent = parts.count >= 3 ? String(parts[2]) : "Bilinmeyen İstemci"
        return (true, agent)
    }

    // MARK: - Asenkron Sağlama Toplamı (Checksum) Hesaplama

    public func calculateHashes(for url: URL) async -> (sha256: String, md5: String)? {
        return await Task.detached(priority: .utility) {
            guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? fileHandle.close() }

            var sha256 = SHA256()
            var md5 = Insecure.MD5()

            let bufferSize = 1024 * 1024 // 1 MB tampon
            while true {
                let data = fileHandle.readData(ofLength: bufferSize)
                if data.isEmpty { break }
                sha256.update(data: data)
                md5.update(data: data)
            }

            let shaDigest = sha256.finalize()
            let shaString = shaDigest.map { String(format: "%02x", $0) }.joined()

            let md5Digest = md5.finalize()
            let md5String = md5Digest.map { String(format: "%02x", $0) }.joined()

            return (sha256: shaString, md5: md5String)
        }.value
    }
}
