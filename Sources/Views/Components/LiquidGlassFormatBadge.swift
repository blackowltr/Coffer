import SwiftUI

/// macOS Apple Human Interface Guidelines standartlarında format rozeti (RAR, ZIP, 7Z, TAR vb.)
public struct LiquidGlassFormatBadge: View {
    public let format: ArchiveFormat
    public var size: BadgeSize = .regular
    public var isSelected: Bool = false

    public enum BadgeSize {
        case small    // Tablo, durum çubuğu ve liste satırları için (yükseklik: 20)
        case regular  // Kartlar, diyaloglar ve formlar için (yükseklik: 26)
        case large    // Başlıklar ve detay sayfaları için (yükseklik: 34)

        var height: CGFloat {
            switch self {
            case .small: return 20
            case .regular: return 26
            case .large: return 34
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .regular: return 11.5
            case .large: return 13.5
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 9
            case .regular: return 11
            case .large: return 13
            }
        }

        var iconSquircleSize: CGFloat {
            switch self {
            case .small: return 14
            case .regular: return 18
            case .large: return 22
            }
        }

        var paddingH: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            case .large: return 12
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 5
            case .regular: return 7
            case .large: return 9
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
            // Sol: Apple Squircle Simgesi
            ZStack {
                RoundedRectangle(cornerRadius: size.cornerRadius * 0.7, style: .continuous)
                    .fill(format.liquidPrimaryColor.opacity(isSelected ? 0.35 : 0.15))

                Image(systemName: format.liquidSymbol)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundColor(format.liquidPrimaryColor)
            }
            .frame(width: size.iconSquircleSize, height: size.iconSquircleSize)

            // Sağ: Format Başlığı
            Text(format.rawValue)
                .font(.system(size: size.fontSize, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? format.liquidPrimaryColor : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal, size.paddingH)
        .frame(maxWidth: expandHorizontally ? .infinity : nil)
        .frame(height: size.height)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(isSelected ? format.liquidPrimaryColor.opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? format.liquidPrimaryColor.opacity(0.60)
                        : Color(NSColor.separatorColor).opacity(0.35),
                    lineWidth: isSelected ? 1.2 : 0.6
                )
        )
    }
}

/// Etkileşimli Apple Format Seçici (Format Picker)
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
            VStack(spacing: 7) {
                // 1. Sıra (Temel Formatlar): RAR, 7Z, ZIP
                HStack(spacing: 8) {
                    formatButton(.rar)
                    formatButton(.sevenZip)
                    formatButton(.zip)
                }

                // 2. Sıra (Unix / Arşiv Formatları): TAR.GZ, TAR.XZ, TAR.BZ2, TAR
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
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
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
