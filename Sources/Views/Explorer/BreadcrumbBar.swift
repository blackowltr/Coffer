import SwiftUI

/// macOS Finder tarzı Apple Yol Çubuğu (Path Bar) ve Entegre Spotlight Arama Bileşeni
public struct BreadcrumbBar: View {
    @ObservedObject private var settings = AppSettings.shared
    public let archiveName: String
    public let currentPath: String
    @Binding public var searchText: String
    public let onNavigateTo: (String) -> Void
    public let onNavigateUp: () -> Void

    @FocusState private var isSearchFocused: Bool

    public init(
        archiveName: String,
        currentPath: String,
        searchText: Binding<String>,
        onNavigateTo: @escaping (String) -> Void,
        onNavigateUp: @escaping () -> Void
    ) {
        self.archiveName = archiveName
        self.currentPath = currentPath
        self._searchText = searchText
        self.onNavigateTo = onNavigateTo
        self.onNavigateUp = onNavigateUp
    }

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    private var pathComponents: [String] {
        if currentPath.isEmpty { return [] }
        return currentPath.split(separator: "/").map(String.init)
    }

    public var body: some View {
        HStack(spacing: 10) {
            // MARK: 1. Üst Dizine Dönüş Butonu (Apple HIG Back Button)
            Button(action: onNavigateUp) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 20, height: 18)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(currentPath.isEmpty)
            .help("Bir üst klasöre dön (⌘↑)")

            // MARK: 2. Hiyerarşik Yol Çubuğu (Finder Path Bar)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Kök Arşiv
                    PathSegmentButton(
                        title: archiveName.isEmpty ? "Ana Dizin" : archiveName,
                        icon: "archivebox",
                        isSelected: currentPath.isEmpty,
                        accentColor: accentColor,
                        action: { onNavigateTo("") }
                    )

                    // Klasör Hiyerarşisi
                    ForEach(0..<pathComponents.count, id: \.self) { index in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))

                        let subPath = pathComponents[0...index].joined(separator: "/")
                        let isLast = index == pathComponents.count - 1

                        PathSegmentButton(
                            title: pathComponents[index],
                            icon: "folder",
                            isSelected: isLast,
                            accentColor: accentColor,
                            action: { onNavigateTo(subPath) }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }

            Spacer()

            // MARK: 3. macOS Standart Arama Çubuğu
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(isSearchFocused ? accentColor : .secondary)

                TextField("Arşivde ara...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .frame(minWidth: 120, idealWidth: 160)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else if !isSearchFocused {
                    Text("⌘F")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color(NSColor.quaternaryLabelColor).opacity(0.4))
                        .cornerRadius(3)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSearchFocused ? accentColor.opacity(0.55) : Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.8)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Tekil Yol Düğmesi (Segment)
private struct PathSegmentButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? accentColor : (isHovered ? .primary : .secondary))

                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : (isHovered ? .primary : .primary.opacity(0.85)))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.12) : (isHovered ? Color(NSColor.selectedControlColor).opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
