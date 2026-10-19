import SwiftUI

/// Arşiv içerisindeki hiyerarşik dizin yolunu (Breadcrumb) ve arama çubuğunu gösteren bileşen
public struct BreadcrumbBar: View {
    @ObservedObject private var settings = AppSettings.shared
    public let archiveName: String
    public let currentPath: String
    @Binding public var searchText: String
    public let onNavigateTo: (String) -> Void
    public let onNavigateUp: () -> Void

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

    private var pathComponents: [String] {
        if currentPath.isEmpty { return [] }
        return currentPath.split(separator: "/").map(String.init)
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Yukarı Dizin Butonu (WinRAR'ın meşhur [..] klasörü)
            Button(action: onNavigateUp) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(settings.accentColorChoice.color)
                    Text("Yukarı")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(currentPath.isEmpty)
            .opacity(currentPath.isEmpty ? 0.35 : 1.0)
            .help("Bir üst klasöre çık (..)")

            Divider()
                .frame(height: 16)

            // Ekmek Kırıntısı (Breadcrumbs)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Kök Arşiv
                    Button(action: { onNavigateTo("") }) {
                        HStack(spacing: 3) {
                            Image(systemName: "archivebox.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(settings.accentColorChoice.color)
                            Text(archiveName.isEmpty ? "Arşiv" : archiveName)
                                .fontWeight(currentPath.isEmpty ? .bold : .regular)
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(currentPath.isEmpty ? settings.accentColorChoice.color.opacity(0.15) : Color.clear)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Alt Klasörler
                    ForEach(0..<pathComponents.count, id: \.self) { index in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)

                        let subPath = pathComponents[0...index].joined(separator: "/")
                        let isLast = index == pathComponents.count - 1

                        Button(action: { onNavigateTo(subPath) }) {
                            Text(pathComponents[index])
                                .font(.system(size: 12))
                                .fontWeight(isLast ? .bold : .regular)
                                .foregroundStyle(isLast ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(isLast ? settings.accentColorChoice.color.opacity(0.15) : Color.clear)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Arşiv İçi Arama Çubuğu
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("Arşivde ara...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 140)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
