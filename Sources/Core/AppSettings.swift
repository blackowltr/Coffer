import SwiftUI

/// Kullanıcı tercihleri ve uygulama ayarları yöneticisi
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    // MARK: - Görünüm ve Efektler
    @AppStorage("enableAnimations") public var enableAnimations: Bool = true
    @AppStorage("selectedTheme") public var selectedTheme: AppTheme = .system
    @AppStorage("accentColorChoice") public var accentColorChoice: AppAccentColor = .blue
    public var accentColor: Color { accentColorChoice.color }
    @AppStorage("enableMenuBarDropZone") public var enableMenuBarDropZone: Bool = true
    @AppStorage("hasCompletedOnboarding") public var hasCompletedOnboarding: Bool = false {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
            objectWillChange.send()
        }
    }

    // MARK: - Sıkıştırma Tercihleri
    @AppStorage("defaultFormat") public var defaultFormat: String = "ZIP"
    @AppStorage("defaultCompressionLevel") public var defaultCompressionLevel: Int = 5 // Normal
    public var defaultCompressionLevelEnum: CompressionLevel {
        CompressionLevel(rawValue: defaultCompressionLevel) ?? .normal
    }
    @AppStorage("stripMacJunkFiles") public var stripMacJunkFiles: Bool = true
    @AppStorage("enableSizeSimulator") public var enableSizeSimulator: Bool = true

    // MARK: - Çıkarma & Akıllı Çıkarma (Anti-Folder-Bomb)
    @AppStorage("enableSmartExtraction") public var enableSmartExtraction: Bool = true // Klasör Bombası Koruması
    @AppStorage("trashArchiveAfterExtract") public var trashArchiveAfterExtract: Bool = false // Çöp Sepeti'ne taşı
    @AppStorage("defaultExtractLocation") public var defaultExtractLocation: String = "sameFolder" // sameFolder, desktop, downloads, ask
    @AppStorage("overwriteExistingFiles") public var overwriteExistingFiles: Bool = true
    @AppStorage("revealInFinderAfterExtract") public var revealInFinderAfterExtract: Bool = true
    @AppStorage("playSoundOnCompletion") public var playSoundOnCompletion: Bool = true

    // MARK: - Alan Açarak Çıkarma (Space-Saver Extraction)
    @AppStorage("enableSpaceSaverMode") public var enableSpaceSaverMode: Bool = false
    @AppStorage("autoEnableSpaceSaverOnLowDisk") public var autoEnableSpaceSaverOnLowDisk: Bool = true
    @AppStorage("spaceSaverSafetyMarginMB") public var spaceSaverSafetyMarginMB: Int = 512

    private init() {}

    public enum AppTheme: String, CaseIterable, Identifiable {
        case system = "Sistem Teması"
        case light = "Açık Tema"
        case dark = "Koyu Tema"

        public var id: String { rawValue }

        public var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    public enum AppAccentColor: String, CaseIterable, Identifiable {
        case blue = "Mavi"
        case purple = "Mor"
        case pink = "Pembe"
        case red = "Kırmızı"
        case orange = "Turuncu"
        case yellow = "Sarı"
        case green = "Yeşil"
        case graphite = "Grafit"

        public var id: String { rawValue }

        public init?(rawValue: String) {
            switch rawValue {
            case "Mavi", "Klasik Mavi", "Derin Safir", "Derin Okyanus", "Okyanus Turkuazı", "Gece İndigosu": self = .blue
            case "Mor", "Asil Mor", "Kozmik Menekşe": self = .purple
            case "Pembe", "Canlı Pembe", "Gül Altını": self = .pink
            case "Kırmızı", "Ateş Kırmızısı", "Değerli Yakut": self = .red
            case "Turuncu", "Sıcak Turuncu", "Alacakaranlık Sunset", "Lav Turuncusu": self = .orange
            case "Sarı", "Altın Sarısı": self = .yellow
            case "Yeşil", "Doğal Yeşil", "Koyu Zümrüt", "Ferah Nane", "Elektrik Yeşili", "Kuzey Işıkları", "Siber Neon": self = .green
            case "Grafit", "Grafit Grisi": self = .graphite
            default: self = .blue
            }
        }

        /// Apple macOS Standart Vurgu Rengi
        public var color: Color {
            switch self {
            case .blue: return Color(red: 0.0, green: 0.48, blue: 1.0)
            case .purple: return Color(red: 0.69, green: 0.32, blue: 0.87)
            case .pink: return Color(red: 0.99, green: 0.18, blue: 0.54)
            case .red: return Color(red: 1.0, green: 0.27, blue: 0.23)
            case .orange: return Color(red: 1.0, green: 0.58, blue: 0.0)
            case .yellow: return Color(red: 1.0, green: 0.80, blue: 0.0)
            case .green: return Color(red: 0.20, green: 0.78, blue: 0.35)
            case .graphite: return Color(red: 0.55, green: 0.55, blue: 0.58)
            }
        }
    }
}
