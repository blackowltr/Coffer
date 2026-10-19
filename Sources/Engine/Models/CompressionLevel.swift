import Foundation

/// WinRAR tarzı sıkıştırma seviyeleri
public enum CompressionLevel: Int, CaseIterable, Identifiable, Sendable {
    case store = 0     // Depola (Sıkıştırma yok - I/O hızında kopyalama)
    case fastest = 1   // En Hızlı (En düşük CPU kullanımı)
    case fast = 3      // Hızlı
    case normal = 5    // Normal (Standart denge)
    case good = 7      // İyi (Yüksek sıkıştırma)
    case best = 9      // En İyi (Maksimum sıkıştırma, LZMA2/Zopfli derin analiz)

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .store: return "Depola (Store)"
        case .fastest: return "En Hızlı (Fastest)"
        case .fast: return "Hızlı (Fast)"
        case .normal: return "Normal (Varsayılan)"
        case .good: return "İyi (Good)"
        case .best: return "En İyi (Maksimum)"
        }
    }

    public var localizedDescription: String {
        switch self {
        case .store: return "Dosyaları sıkıştırmadan paketler. Sıfır CPU yükü, anında bitiş."
        case .fastest: return "Minimum sıkıştırma oranı, yüksek hız."
        case .fast: return "Hızlı paketleme, temel sıkıştırma."
        case .normal: return "Hız ve dosya boyutu arasında ideal denge."
        case .good: return "Daha küçük dosya boyutu için gelişmiş algoritmalar."
        case .best: return "Mümkün olan en küçük arşiv boyutu için gelişmiş sıkıştırma algoritmaları."
        }
    }

    /// CLI komutlarında kullanılan sayısal bayrak (-0 ... -9)
    public var cliFlag: String {
        return "-\(rawValue)"
    }
}
