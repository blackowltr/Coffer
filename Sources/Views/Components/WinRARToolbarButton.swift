import SwiftUI

/// WinRAR'ın klasik araç çubuğu ikonlarını modern Apple macOS estetiğiyle birleştiren yüksek kaliteli buton bileşeni
public struct WinRARToolbarButton: View {
    public let title: String
    public let icon: String
    public let color: Color
    public let shortcut: KeyEquivalent?
    public let action: () -> Void

    @State private var isHovered: Bool = false

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
                                colors: [
                                    color.opacity(isHovered ? 0.25 : 0.16),
                                    color.opacity(isHovered ? 0.14 : 0.07)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 36, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(isHovered ? 0.55 : 0.32),
                                            color.opacity(isHovered ? 0.30 : 0.14)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: color.opacity(isHovered ? 0.25 : 0.08), radius: isHovered ? 4 : 2, x: 0, y: 1)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(color)
                        .scaleEffect(isHovered ? 1.06 : 1.0)
                }

                Text(title)
                    .font(.system(size: 11, weight: isHovered ? .semibold : .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            .frame(width: 62, height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
        .help(title)
    }
}
