import SwiftUI

/// WinRAR tarzı detaylı arşiv özellikleri ve teknik bilgi diyaloğu
public struct ArchiveInfoDialog: View {
    public let metadata: ArchiveMetadata
    @Binding public var isPresented: Bool

    public init(metadata: ArchiveMetadata, isPresented: Binding<Bool>) {
        self.metadata = metadata
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Başlık
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppSettings.shared.accentColorChoice.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Arşiv Bilgileri & İstatistikler")
                        .font(.headline)
                    Text(metadata.archiveURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            VStack(spacing: 14) {
                // Genel Özellikler
                GroupBox("Genel Özellikler") {
                    VStack(spacing: 8) {
                        infoRow("Arşiv Biçimi:", "\(metadata.format.rawValue) (\(metadata.format.localizedDescription))")
                        infoRow("Arşiv Boyutu:", metadata.formattedArchiveSize)
                        infoRow("Orijinal Boyut:", metadata.formattedUncompressedSize)
                        infoRow("Sıkıştırma Tasarrufu:", "%\(String(format: "%.1f", metadata.overallSavingsRatio))")
                        infoRow("Dosya Sayısı:", "\(metadata.totalFileCount) adet")
                        infoRow("Klasör Sayısı:", "\(metadata.totalDirectoryCount) adet")
                    }
                    .padding(6)
                }

                // Güvenlik ve Bütünlük
                GroupBox("Güvenlik ve Bütünlük") {
                    VStack(spacing: 8) {
                        infoRow("Şifreleme:", metadata.isEncrypted ? "🔒 Parola Korumalı (AES)" : "Korumasız")
                        infoRow("Çok Parçalı (Split):", metadata.isMultiVolume ? "Evet (Ciltli Arşiv)" : "Hayır (Tek Parça)")
                        infoRow("Kurtarma Kaydı (RR):", metadata.hasRecoveryRecord ? "Mevcut (\(String(format: "%.0f", metadata.recoveryRecordPercentage ?? 3))%)" : "Yok")
                    }
                    .padding(6)
                }
            }
            .padding(18)

            Divider()

            HStack {
                Spacer()
                Button("Tamam") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 440)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .trailing)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

/// WinRAR Bütünlük Testi Sonuç Penceresi
public struct TestResultDialog: View {
    public let result: ArchiveTestResult
    @Binding public var isPresented: Bool

    public init(result: ArchiveTestResult, isPresented: Binding<Bool>) {
        self.result = result
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: result.isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(result.isSuccess ? .green : .red)

            VStack(spacing: 6) {
                Text(result.isSuccess ? "Bütünlük Testi Başarılı" : "Arşivde Hatalar Bulundu!")
                    .font(.headline)

                if result.isSuccess {
                    Text("Tüm dosyaların sağlama toplamları (CRC) doğrulandı. Arşiv tamamen sağlam.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Arşiv dosyalarında bozulma veya CRC hatası tespit edildi.")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 4) {
                Text("Denetlenen Öğe: \(result.totalItemsChecked) adet")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if result.duration > 0 {
                    Text("Süre: \(String(format: "%.2f", result.duration)) saniye")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            if !result.errors.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.errors, id: \.self) { err in
                            Text(err)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 80)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
            }

            Button("Tamam") {
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: 380)
    }
}
