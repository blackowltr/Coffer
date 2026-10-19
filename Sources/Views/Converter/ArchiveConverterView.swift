import SwiftUI

/// Arşivi doğrudan farklı bir formata dönüştürme penceresi (.rar -> .7z vb.)
public struct ArchiveConverterView: View {
    public let sourceURL: URL
    @Binding public var isPresented: Bool
    public let onStartConversion: (ArchiveFormat, CompressionLevel, URL) -> Void

    @State private var targetFormat: ArchiveFormat = .sevenZip
    @State private var targetLevel: CompressionLevel = .good
    @State private var destinationDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    @State private var targetFileName: String = ""

    public init(
        sourceURL: URL,
        isPresented: Binding<Bool>,
        onStartConversion: @escaping (ArchiveFormat, CompressionLevel, URL) -> Void
    ) {
        self.sourceURL = sourceURL
        self._isPresented = isPresented
        self.onStartConversion = onStartConversion
        let baseName = (sourceURL.lastPathComponent as NSString).deletingPathExtension
        self._targetFileName = State(initialValue: baseName)
    }

    private var targetFileURL: URL {
        let name = targetFileName.isEmpty ? "Dönüştürülen_Arşiv" : targetFileName
        return destinationDirectory.appendingPathComponent("\(name).\(targetFormat.primaryExtension)")
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Başlık
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Arşiv Biçimini Dönüştür")
                        .font(.headline)
                    Text("'\(sourceURL.lastPathComponent)' arşivini açmadan farklı bir biçime çevirin.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(18)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                // Kaynak ve Hedef Format
                GroupBox("Biçim Seçimi") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            Text("Mevcut Biçim:")
                                .frame(width: 100, alignment: .trailing)
                                .font(.system(size: 12))

                            if let currentFmt = ArchiveFormat.detect(from: sourceURL) {
                                LiquidGlassFormatBadge(format: currentFmt, size: .small)
                            } else {
                                Text("Bilinmiyor")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(4)
                            }
                        }

                        HStack(alignment: .center) {
                            Text("Hedef Biçim:")
                                .frame(width: 100, alignment: .trailing)
                                .font(.system(size: 12))

                            LiquidGlassFormatPicker(
                                selection: $targetFormat,
                                formats: [.sevenZip, .zip, .tarGz, .tarXz, .tarBz2]
                            )
                        }

                        HStack {
                            Text("Sıkıştırma:")
                                .frame(width: 120, alignment: .trailing)
                                .font(.system(size: 12))

                            Picker("", selection: $targetLevel) {
                                ForEach(CompressionLevel.allCases) { lvl in
                                    Text(lvl.title).tag(lvl)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .padding(6)
                }

                // Hedef Dosya Adı ve Konumu
                GroupBox("Hedef Dosya ve Konum") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Dosya Adı:")
                                .frame(width: 120, alignment: .trailing)
                                .font(.system(size: 12))

                            TextField("Arşiv adı", text: $targetFileName)
                                .textFieldStyle(.roundedBorder)

                            Text(".\(targetFormat.primaryExtension)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Kayıt Yeri:")
                                .frame(width: 120, alignment: .trailing)
                                .font(.system(size: 12))

                            Text(destinationDirectory.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Gözat...") {
                                chooseDestination()
                            }
                            .font(.system(size: 11))
                        }
                    }
                    .padding(6)
                }
            }
            .padding(20)

            Spacer()
            Divider()

            HStack {
                Button("İptal") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Dönüştür") {
                    isPresented = false
                    onStartConversion(targetFormat, targetLevel, targetFileURL)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 480, height: 430)
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Konum Seç"
        if panel.runModal() == .OK, let url = panel.url {
            destinationDirectory = url
        }
    }
}
