import SwiftUI

/// Apple Liquid Glass tarzı format rozeti (RAR, ZIP, 7Z, TAR vb.)
public struct LiquidGlassFormatBadge: View {
    public let format: ArchiveFormat
    public var size: BadgeSize = .regular
    public var isSelected: Bool = false

    public enum BadgeSize {
        case small    // Tablo, durum çubuğu ve liste satırları için (yükseklik: 20)
        case regular  // Kartlar, diyaloglar ve formlar için (yükseklik: 28)
        case large    // Başlıklar ve detay sayfaları için (yükseklik: 38)

        var height: CGFloat {
            switch self {
            case .small: return 20
            case .regular: return 28
            case .large: return 38
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .regular: return 12
            case .large: return 15
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 9
            case .regular: return 11
            case .large: return 15
            }
        }

        var iconSquircleSize: CGFloat {
            switch self {
            case .small: return 14
            case .regular: return 18
            case .large: return 24
            }
        }

        var paddingH: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 9
            case .large: return 14
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            case .large: return 11
            }
        }
    }

    public var expandHorizontally: Bool = false

    public init(format: ArchiveFormat, size: BadgeSize = .regular, isSelected: Bool = false, expandHorizontally: Bool = false) {
        self.format = format
        self.size = size
        self.isSelected = isSelected
        self.expandHorizontally = expandHorizontally
    }

    public var body: some View {
        HStack(spacing: size == .small ? 4 : 6) {
            // Sol: Sıvı Cam Squircle Simgesi
            ZStack {
                RoundedRectangle(cornerRadius: size.cornerRadius * 0.7, style: .continuous)
                    .fill(format.liquidGradient)

                // Üst Cam Yansıma Parıltısı
                RoundedRectangle(cornerRadius: size.cornerRadius * 0.7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                Image(systemName: format.liquidSymbol)
                    .font(.system(size: size.iconSize, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size.iconSquircleSize, height: size.iconSquircleSize)
            .shadow(color: format.liquidPrimaryColor.opacity(0.35), radius: 2, y: 1)

            // Sağ: Format Başlığı
            Text(format.rawValue)
                .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal, size.paddingH)
        .frame(maxWidth: expandHorizontally ? .infinity : nil)
        .frame(height: size.height)
        .background(
            ZStack {
                if isSelected {
                    // Seçili Durum: Neon Sıvı Cam Arka Planı
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(format.liquidGradient)

                    // Üst Parlaklık
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Normal Durum: Buzlu Sıvı Cam (Frosted Glass Substrate)
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))

                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .fill(format.liquidPrimaryColor.opacity(0.08))
                }
            }
        )
        // Sıvı Cam Kenarlık (Specular Reflection Rim)
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isSelected
                            ? [Color.white.opacity(0.8), format.liquidSecondaryColor.opacity(0.6)]
                            : [Color.white.opacity(0.65), Color.black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 1.5 : 1.0
                )
        )
        .shadow(
            color: isSelected ? format.liquidPrimaryColor.opacity(0.40) : Color.black.opacity(0.04),
            radius: isSelected ? 6 : 2,
            y: isSelected ? 2 : 1
        )
    }
}

/// Etkileşimli Apple Liquid Glass Format Seçici (Format Picker)
public struct LiquidGlassFormatPicker: View {
    @Binding public var selection: ArchiveFormat
    public var customFormats: [ArchiveFormat]? = nil

    public init(selection: Binding<ArchiveFormat>, formats: [ArchiveFormat]? = nil) {
        self._selection = selection
        self.customFormats = formats
    }

    public var body: some View {
        if let list = customFormats {
            HStack(spacing: 8) {
                ForEach(list) { fmt in
                    formatButton(fmt)
                }
            }
        } else {
            // 2 Sıralı Kusursuz Simetrik Düzen (Kenarlardan Taşmayan, Tam Eşit Dağılım)
            VStack(spacing: 7) {
                // 1. Sıra (3 Temel Format - Eşit 1/3 Genişlik): RAR, 7Z, ZIP
                HStack(spacing: 8) {
                    formatButton(.rar)
                    formatButton(.sevenZip)
                    formatButton(.zip)
                }

                // 2. Sıra (4 Unix / Açık Format - Eşit 1/4 Genişlik): TAR.GZ, TAR.XZ, TAR.BZ2, TAR
                HStack(spacing: 8) {
                    formatButton(.tarGz)
                    formatButton(.tarXz)
                    formatButton(.tarBz2)
                    formatButton(.tar)
                }
            }
        }
    }

    private func formatButton(_ fmt: ArchiveFormat) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selection = fmt
            }
        }) {
            LiquidGlassFormatBadge(
                format: fmt,
                size: .regular,
                isSelected: selection == fmt,
                expandHorizontally: true
            )
        }
        .buttonStyle(.plain)
    }
}
