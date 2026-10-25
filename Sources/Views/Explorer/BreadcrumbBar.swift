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
            // MARK: 1. Üst Dizine Dönüş Butonu (Apple Style Back / Up Chevron)
            Button(action: onNavigateUp) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(currentPath.isEmpty ? .secondary.opacity(0.35) : .primary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color(NSColor.controlBackgroundColor).opacity(currentPath.isEmpty ? 0.3 : 0.75))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color(NSColor.separatorColor).opacity(currentPath.isEmpty ? 0.15 : 0.3), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(currentPath.isEmpty)
            .help("Bir üst klasöre dön (⌘↑)")

            // MARK: 2. Hiyerarşik Yol Kapsülü (Interactive Breadcrumb Capsule)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    // Kök Arşiv
                    PathSegmentButton(
                        title: archiveName.isEmpty ? "Ana Dizin" : archiveName,
                        icon: "archivebox.fill",
                        isSelected: currentPath.isEmpty,
                        accentColor: accentColor,
                        action: { onNavigateTo("") }
                    )

                    // Klasör Hiyerarşisi
                    ForEach(0..<pathComponents.count, id: \.self) { index in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 1)

                        let subPath = pathComponents[0...index].joined(separator: "/")
                        let isLast = index == pathComponents.count - 1

                        PathSegmentButton(
                            title: pathComponents[index],
                            icon: "folder.fill",
                            isSelected: isLast,
                            accentColor: accentColor,
                            action: { onNavigateTo(subPath) }
                        )
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
            }

            Spacer()

            // MARK: 3. Spotlight Tarzı Arama Çubuğu (Spotlight Search Pill)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSearchFocused ? accentColor : .secondary)

                TextField("Arşivde ara...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .frame(minWidth: 110, idealWidth: 150)
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
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(NSColor.quaternaryLabelColor).opacity(0.5))
                        .cornerRadius(3)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.85))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSearchFocused ? accentColor.opacity(0.5) : Color(NSColor.separatorColor).opacity(0.35), lineWidth: isSearchFocused ? 1 : 0.5)
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSearchFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
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
