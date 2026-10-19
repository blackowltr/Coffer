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
    @AppStorage("enable3DDepthTilt") public var enable3DDepthTilt: Bool = false

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
        // Mavi & Safir Grubu
        case blue = "Klasik Mavi"
        case sapphire = "Derin Safir"
        case deepOcean = "Derin Okyanus"
        case cyan = "Okyanus Turkuazı"
        case indigo = "Gece İndigosu"

        // Mor & Pembe Grubu
        case purple = "Asil Mor"
        case cosmicViolet = "Kozmik Menekşe"
        case pink = "Canlı Pembe"
        case roseGold = "Gül Altını"

        // Kırmızı & Turuncu Grubu
        case red = "Ateş Kırmızısı"
        case ruby = "Değerli Yakut"
        case orange = "Sıcak Turuncu"
        case sunset = "Alacakaranlık Sunset"
        case lava = "Lav Turuncusu"
        case amber = "Altın Sarısı"

        // Yeşil & Doğa Grubu
        case emerald = "Koyu Zümrüt"
        case green = "Doğal Yeşil"
        case mint = "Ferah Nane"
        case electricLime = "Elektrik Yeşili"

        // Sahne & Özel Efekt Grubu
        case aurora = "Kuzey Işıkları"
        case cyberNeon = "Siber Neon"
        case graphite = "Grafit Grisi"

        public var id: String { rawValue }

        /// Birincil Vurgu Rengi
        public var color: Color {
            switch self {
            case .blue: return Color(red: 0.05, green: 0.50, blue: 1.0)
            case .sapphire: return Color(red: 0.08, green: 0.38, blue: 0.88)
            case .deepOcean: return Color(red: 0.0, green: 0.45, blue: 0.65)
            case .cyan: return Color(red: 0.12, green: 0.72, blue: 0.88)
            case .indigo: return Color(red: 0.35, green: 0.34, blue: 0.84)

            case .purple: return Color(red: 0.68, green: 0.32, blue: 0.88)
            case .cosmicViolet: return Color(red: 0.55, green: 0.20, blue: 0.95)
            case .pink: return Color(red: 0.98, green: 0.25, blue: 0.55)
            case .roseGold: return Color(red: 0.94, green: 0.48, blue: 0.52)

            case .red: return Color(red: 0.95, green: 0.22, blue: 0.22)
            case .ruby: return Color(red: 0.85, green: 0.12, blue: 0.28)
            case .orange: return Color(red: 1.0, green: 0.55, blue: 0.0)
            case .sunset: return Color(red: 1.0, green: 0.42, blue: 0.25)
            case .lava: return Color(red: 1.0, green: 0.28, blue: 0.05)
            case .amber: return Color(red: 1.0, green: 0.76, blue: 0.05)

            case .emerald: return Color(red: 0.08, green: 0.65, blue: 0.42)
            case .green: return Color(red: 0.20, green: 0.78, blue: 0.35)
            case .mint: return Color(red: 0.25, green: 0.82, blue: 0.68)
            case .electricLime: return Color(red: 0.60, green: 0.90, blue: 0.12)

            case .aurora: return Color(red: 0.15, green: 0.85, blue: 0.65)
            case .cyberNeon: return Color(red: 0.0, green: 0.95, blue: 0.95)
            case .graphite: return Color(red: 0.55, green: 0.55, blue: 0.58)
            }
        }

        /// Sahne Arkası Işıklandırma için İkincil / Tamamlayıcı Renk
        public var secondaryColor: Color {
            switch self {
            case .blue: return Color(red: 0.38, green: 0.22, blue: 0.95)
            case .sapphire: return Color(red: 0.0, green: 0.70, blue: 0.85)
            case .deepOcean: return Color(red: 0.10, green: 0.75, blue: 0.60)
            case .cyan: return Color(red: 0.45, green: 0.25, blue: 0.95)
            case .indigo: return Color(red: 0.85, green: 0.25, blue: 0.75)

            case .purple: return Color(red: 0.95, green: 0.30, blue: 0.65)
            case .cosmicViolet: return Color(red: 0.20, green: 0.55, blue: 1.0)
            case .pink: return Color(red: 1.0, green: 0.55, blue: 0.20)
            case .roseGold: return Color(red: 0.98, green: 0.70, blue: 0.55)

            case .red: return Color(red: 1.0, green: 0.50, blue: 0.0)
            case .ruby: return Color(red: 0.60, green: 0.15, blue: 0.75)
            case .orange: return Color(red: 0.95, green: 0.15, blue: 0.45)
            case .sunset: return Color(red: 0.75, green: 0.20, blue: 0.85)
            case .lava: return Color(red: 1.0, green: 0.75, blue: 0.10)
            case .amber: return Color(red: 1.0, green: 0.35, blue: 0.10)

            case .emerald: return Color(red: 0.05, green: 0.55, blue: 0.85)
            case .green: return Color(red: 0.10, green: 0.80, blue: 0.75)
            case .mint: return Color(red: 0.20, green: 0.50, blue: 0.95)
            case .electricLime: return Color(red: 0.05, green: 0.80, blue: 0.65)

            case .aurora: return Color(red: 0.65, green: 0.25, blue: 0.95)
            case .cyberNeon: return Color(red: 1.0, green: 0.15, blue: 0.65)
            case .graphite: return Color(red: 0.30, green: 0.35, blue: 0.45)
            }
        }
    }
}
