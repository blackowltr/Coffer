import SwiftUI

/// Apple macOS Human Interface Guidelines standartlarında, zengin ve modern Markdown Sürüm Notları / Yenilikler Görünümü
public struct ReleaseNotesMarkdownView: View {
    @ObservedObject private var settings = AppSettings.shared
    public let markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    private var accentColor: Color {
        settings.accentColorChoice.color
    }

    private var parsedSections: [ReleaseNotesSection] {
        ReleaseNotesParser.parse(markdown)
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(parsedSections) { section in
                    renderSection(section)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func renderSection(_ section: ReleaseNotesSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Bölüm Başlığı
            if let title = section.title {
                HStack(spacing: 8) {
                    if let icon = section.icon {
                        Text(icon)
                            .font(.system(size: 15))
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(section.isPrimaryHeader ? .primary : accentColor)

                    Spacer()
                }
                .padding(.top, section.isPrimaryHeader ? 2 : 6)

                if section.isPrimaryHeader {
                    Divider()
                        .opacity(0.5)
                        .padding(.bottom, 2)
                }
            }

            // Düz Paragraflar
            ForEach(section.paragraphs, id: \.self) { para in
                Text(parseInlineMarkdown(para))
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Özellik Kartları / Maddeler
            if !section.items.isEmpty {
                VStack(spacing: 8) {
                    ForEach(section.items) { item in
                        renderItemCard(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderItemCard(_ item: ReleaseFeatureItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            // Sol İkon / Emoji Rozeti
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.16), accentColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)

                Text(item.icon ?? "✨")
                    .font(.system(size: 14))
            }
            .padding(.top, 1)

            // Başlık & Açıklama
            VStack(alignment: .leading, spacing: 3) {
                if !item.title.isEmpty {
                    Text(parseInlineMarkdown(item.title))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.primary)
                }

                if !item.description.isEmpty {
                    Text(parseInlineMarkdown(item.description))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 0.5)
        )
    }

    /// Inline Markdown (*bold*, `code`, link) güvenli şekilde AttributedString'e çevirir
    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        if let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attr
        }
        return AttributedString(text)
    }
}

// MARK: - Veri Modelleri
public struct ReleaseNotesSection: Identifiable {
    public let id = UUID()
    public var title: String?
    public var icon: String?
    public var isPrimaryHeader: Bool = false
    public var paragraphs: [String] = []
    public var items: [ReleaseFeatureItem] = []
}

public struct ReleaseFeatureItem: Identifiable {
    public let id = UUID()
    public var icon: String?
    public var title: String
    public var description: String
}

// MARK: - Sürüm Notları Markdown Ayrıştırıcısı
public struct ReleaseNotesParser {
    public static func parse(_ text: String) -> [ReleaseNotesSection] {
        var sections: [ReleaseNotesSection] = []
        var currentSection = ReleaseNotesSection()

        let lines = text.components(separatedBy: .newlines)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // 1. Ana Başlık (## )
            if line.hasPrefix("## ") {
                if !currentSection.paragraphs.isEmpty || !currentSection.items.isEmpty || currentSection.title != nil {
                    sections.append(currentSection)
                    currentSection = ReleaseNotesSection()
                }
                let clean = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let (icon, title) = extractLeadingIcon(clean)
                currentSection.title = title
                currentSection.icon = icon
                currentSection.isPrimaryHeader = true
                continue
            }

            // 2. Alt Başlık (### )
            if line.hasPrefix("### ") {
                if !currentSection.paragraphs.isEmpty || !currentSection.items.isEmpty || currentSection.title != nil {
                    sections.append(currentSection)
                    currentSection = ReleaseNotesSection()
                }
                let clean = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                let (icon, title) = extractLeadingIcon(clean)
                currentSection.title = title
                currentSection.icon = icon
                currentSection.isPrimaryHeader = false
                continue
            }

            // 3. Madde İmi / Bullet List (- , * , • )
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                let clean = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let (itemIcon, rest) = extractLeadingIcon(clean)

                if let (title, desc) = extractBoldTitleAndDesc(rest) {
                    currentSection.items.append(ReleaseFeatureItem(icon: itemIcon, title: title, description: desc))
                } else {
                    currentSection.items.append(ReleaseFeatureItem(icon: itemIcon, title: clean, description: ""))
                }
                continue
            }

            // 4. Standart Paragraf
            currentSection.paragraphs.append(line)
        }

        if !currentSection.paragraphs.isEmpty || !currentSection.items.isEmpty || currentSection.title != nil {
            sections.append(currentSection)
        }

        return sections
    }

    /// Satır başındaki emoji veya sembolü ayıklar
    private static func extractLeadingIcon(_ text: String) -> (icon: String?, rest: String) {
        guard let first = text.unicodeScalars.first, (first.properties.isEmoji && !first.isASCII) || first.value == 0x2728 || first.value == 0x26A1 else {
            return (nil, text)
        }
        var iconStr = ""
        for char in text {
            if char.unicodeScalars.allSatisfy({ ($0.properties.isEmoji && !$0.isASCII) || $0.properties.isEmojiPresentation || $0.value == 0x2728 || $0.value == 0x26A1 }) {
                iconStr.append(char)
            } else {
                break
            }
        }
        let rest = String(text.dropFirst(iconStr.count)).trimmingCharacters(in: .whitespaces)
        return (iconStr.isEmpty ? nil : iconStr, rest)
    }

    /// **Başlık:** Açıklama veya **Başlık** Açıklama yapısını ayıklar
    private static func extractBoldTitleAndDesc(_ text: String) -> (title: String, desc: String)? {
        guard text.hasPrefix("**") else { return nil }
        let afterStart = text.dropFirst(2)
        guard let endRange = afterStart.range(of: "**") else { return nil }

        let rawTitle = String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        var desc = String(afterStart[endRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        if desc.hasPrefix(":") {
            desc = String(desc.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        let cleanTitle = rawTitle.hasSuffix(":") ? String(rawTitle.dropLast()).trimmingCharacters(in: .whitespaces) : rawTitle
        return (cleanTitle, desc)
    }
}
