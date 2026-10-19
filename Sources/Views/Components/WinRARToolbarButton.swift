import SwiftUI

/// WinRAR'ın klasik araç çubuğu ikonlarını modern Apple macOS estetiğiyle birleştiren buton bileşeni
public struct WinRARToolbarButton: View {
    public let title: String
    public let icon: String
    public let color: Color
    public let shortcut: KeyEquivalent?
    public let action: () -> Void

    public init(
        title: String,
        icon: String,
        color: Color = AppSettings.shared.accentColorChoice.color,
        shortcut: KeyEquivalent? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.shortcut = shortcut
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.18), color.opacity(0.09)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 34, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [color.opacity(0.38), color.opacity(0.18)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: color.opacity(0.12), radius: 2, x: 0, y: 1)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            .frame(width: 60, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
