import SwiftUI

public enum ConflictResolutionChoice {
    case overwrite
    case autoRename
    case skip
    case cancel
}

/// Dosya çıkarma sırasında hedefte aynı isimde dosya bulunduğunda kullanıcıya soran şık macOS modal penceresi
public struct ExtractionConflictDialog: View {
    @ObservedObject private var settings = AppSettings.shared
    public let conflictingFileName: String
    public let existingFileSize: Int64?
    public let existingFileDate: Date?
    public let incomingFileSize: Int64
    public let incomingFileDate: Date?
    public let onResolve: (ConflictResolutionChoice, Bool) -> Void

    @State private var applyToAll: Bool = false

    public init(
        conflictingFileName: String,
        existingFileSize: Int64? = nil,
        existingFileDate: Date? = nil,
        incomingFileSize: Int64,
        incomingFileDate: Date? = nil,
        onResolve: @escaping (ConflictResolutionChoice, Bool) -> Void
    ) {
        self.conflictingFileName = conflictingFileName
        self.existingFileSize = existingFileSize
        self.existingFileDate = existingFileDate
        self.incomingFileSize = incomingFileSize
        self.incomingFileDate = incomingFileDate
        self.onResolve = onResolve
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(settings.accentColorChoice.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(settings.accentColorChoice.color)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("conflict.title".loc)
                        .font(.system(size: 15, weight: .bold))
                    Text("\"\(conflictingFileName)\" " + ("conflict.message".loc))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            // Dosya Karşılaştırma Kutusu
            HStack(spacing: 12) {
                // Mevcut Dosya
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hedefteki Dosya:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    if let sz = existingFileSize {
                        Text(ByteCountFormatter.string(fromByteCount: sz, countStyle: .file))
                            .font(.system(size: 12, design: .monospaced))
                    }
                    if let dt = existingFileDate {
                        Text(dt, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.secondary.opacity(0.6))

                // Arşivdeki Dosya
                VStack(alignment: .leading, spacing: 3) {
                    Text("Arşivdeki Dosya:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(settings.accentColorChoice.color)
                    Text(ByteCountFormatter.string(fromByteCount: incomingFileSize, countStyle: .file))
                        .font(.system(size: 12, design: .monospaced))
                    if let dt = incomingFileDate {
                        Text(dt, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(settings.accentColorChoice.color.opacity(0.08))
                .cornerRadius(8)
            }

            Toggle("conflict.applyAll".loc, isOn: $applyToAll)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 10) {
                Button("conflict.cancel".loc) {
                    onResolve(.cancel, applyToAll)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("conflict.autoRename".loc) {
                    onResolve(.autoRename, applyToAll)
                }

                Button("conflict.overwrite".loc) {
                    onResolve(.overwrite, applyToAll)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
