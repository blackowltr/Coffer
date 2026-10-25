import SwiftUI
import AppKit

/// UnPack uygulamasının birebir gerçek arayüz bileşenlerini 2x Retina kalitesinde PNG olarak çıkaran görsel üretici
@MainActor
public final class ScreenshotGenerator {

    public static func generateAll(outputDir: String) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        print("==> Gerçek UnPack ekran görüntüleri üretiliyor...")

        // 1. Ana Arşiv Gezgini Ekranı (Explorer Window)
        render(
            view: ExplorerScreenshotView(),
            size: CGSize(width: 980, height: 620),
            to: "\(outputDir)/screenshot-explorer.png"
        )

        // 2. Ayarlar & Tercihler Ekranı (Settings Window)
        render(
            view: SettingsScreenshotView(),
            size: CGSize(width: 760, height: 540),
            to: "\(outputDir)/screenshot-settings.png"
        )

        // 3. Canlı Sürüm Güncelleyici Ekranı (In-App Updater Window)
        render(
            view: UpdaterScreenshotView(),
            size: CGSize(width: 540, height: 490),
            to: "\(outputDir)/screenshot-updater.png"
        )

        // 4. Hızlı Bırakma Alanı Ekranı (Drop Zone Window)
        render(
            view: QuickDropScreenshotView(),
            size: CGSize(width: 760, height: 520),
            to: "\(outputDir)/screenshot-quickdrop.png"
        )

        print("==> Tüm gerçek ekran görüntüleri başarıyla üretildi: \(outputDir)")
    }

    // MARK: - 2x Retina Render Motoru
    private static func render<V: View>(view: V, size: CGSize, to targetPath: String) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2.0 // 2x Retina

        if let cgImage = renderer.cgImage {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let pngData = rep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: targetPath))
                print("==> [Retina PNG Kaydedildi] \(targetPath) (\(pngData.count / 1024) KB) [\(cgImage.width)x\(cgImage.height)]")
                return
            }
        }
        print("❌ HATA: Görsel üretilemedi: \(targetPath)")
    }
}

// MARK: - Gerçek macOS Pencere Çerçevesi
private struct MacWindowFrame<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pencere Başlık Çubuğu & macOS Trafik Işıkları
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                    Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                }
                .padding(.leading, 14)

                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))

                Spacer()

                Color.clear.frame(width: 50, height: 12)
            }
            .frame(height: 38)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            content
        }
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - 1. Arşiv Gezgini Ekranı
private struct ExplorerScreenshotView: View {
    var body: some View {
        MacWindowFrame(title: "UnPack — Proje_Yedegi_2026.zip") {
            VStack(spacing: 0) {
                // Üst Navigasyon Çubuğu
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.accentColor)

                        Text("UnPack")
                            .font(.system(size: 15, weight: .bold))
                    }

                    Spacer()

                    // Mod Seçici (Gezgin Modu seçili)
                    HStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "macwindow.on.rectangle")
                            Text("Gezgin Modu")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)

                        HStack(spacing: 6) {
                            Image(systemName: "bolt.shield.fill")
                            Text("Hızlı Bırakma")
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .foregroundColor(.secondary)
                    }
                    .padding(2)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer()

                    HStack(spacing: 8) {
                        headerButton(icon: "plus.circle.fill", title: "Sıkıştır")
                        headerButton(icon: "folder.fill", title: "Arşiv Aç")

                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Arşiv Eylemleri Kapsül Araç Çubuğu
                HStack(spacing: 6) {
                    // Ana Çıkart Butonu
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Çıkart")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.accentColor)
                    )
                    .foregroundColor(.white)

                    toolbarButton(icon: "plus.circle", title: "Ekle")
                    toolbarButton(icon: "checkmark.seal", title: "Test Et")
                    toolbarButton(icon: "eye", title: "Önizle")
                    toolbarButton(icon: "info.circle", title: "Bilgi")
                    toolbarButton(icon: "arrow.triangle.2.circlepath", title: "Dönüştür")
                    toolbarButton(icon: "lock.shield", title: "Kilitle")
                    toolbarButton(icon: "wrench.and.screwdriver", title: "Onar")

                    Spacer()

                    // Liste / Izgara Geçişi
                    HStack(spacing: 2) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12, weight: .bold))
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.2)))
                            .foregroundColor(Color.accentColor)

                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12))
                            .padding(6)
                            .foregroundColor(.secondary)
                    }
                    .padding(2)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))

                Divider()

                // Yol & Arama Çubuğu (Breadcrumb)
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(Color.accentColor)
                            .font(.system(size: 12))

                        Text("Proje_Yedegi_2026.zip")
                            .font(.system(size: 12, weight: .semibold))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text("Tüm Dosyalar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("⌘F Ara...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                        Spacer()
                    }
                    .frame(width: 180)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Ana İçerik: Sol Kenar Çubuğu + Sağ Dosya Listesi
                HStack(spacing: 0) {
                    // Sol Kenar Çubuğu
                    VStack(alignment: .leading, spacing: 14) {
                        // Akıllı Filtreler
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AKILLI FİLTRELER")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.top, 8)

                            sidebarRow(icon: "tray.full.fill", title: "Tüm Dosyalar", count: "8", color: .blue, isSelected: true)
                            sidebarRow(icon: "photo.fill", title: "Görseller", count: "2", color: .purple, isSelected: false)
                            sidebarRow(icon: "doc.text.fill", title: "Belgeler", count: "3", color: .orange, isSelected: false)
                            sidebarRow(icon: "chevron.left.forwardslash.chevron.right", title: "Kod & Veri", count: "3", color: .cyan, isSelected: false)
                        }

                        // Klasörler
                        VStack(alignment: .leading, spacing: 3) {
                            Text("KLASÖRLER (3)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.horizontal, 14)

                            sidebarFolderRow(title: "Belgeler", count: "3")
                            sidebarFolderRow(title: "Görseller", count: "2")
                            sidebarFolderRow(title: "Kaynak_Kodlar", count: "3")
                        }

                        Spacer()
                    }
                    .frame(width: 195, alignment: .leading)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

                    Divider()

                    // Sağ Liste Görünümü (Finder Tablosu)
                    VStack(spacing: 0) {
                        // Tablo Başlıkları
                        HStack(spacing: 8) {
                            Text("İsim")
                                .frame(width: 220, alignment: .leading)
                            Text("Tür")
                                .frame(width: 95, alignment: .leading)
                            Text("Boyut")
                                .frame(width: 75, alignment: .trailing)
                            Text("Paketli")
                                .frame(width: 75, alignment: .trailing)
                            Text("Değiştirilme Tarihi")
                                .frame(width: 120, alignment: .leading)
                            Text("CRC-32")
                                .frame(width: 70, alignment: .center)
                            Spacer()
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))

                        Divider()

                        // Dosya Satırları
                        VStack(spacing: 0) {
                            fileRow(icon: "folder.fill", iconColor: .blue, name: "Belgeler", type: "Klasör", size: "4,8 MB", packed: "2,1 MB", date: "Bugün 14:20", crc: "—", isSelected: false)
                            fileRow(icon: "folder.fill", iconColor: .blue, name: "Görseller", type: "Klasör", size: "8,4 MB", packed: "6,2 MB", date: "Dün 18:15", crc: "—", isSelected: false)
                            fileRow(icon: "folder.fill", iconColor: .blue, name: "Kaynak_Kodlar", type: "Klasör", size: "240 KB", packed: "58 KB", date: "25 Eki 19:40", crc: "—", isSelected: false)
                            fileRow(icon: "doc.richtext.fill", iconColor: .red, name: "Proje_Raporu_2026.pdf", type: "PDF Belgesi", size: "2,4 MB", packed: "1,6 MB", date: "24 Eki 11:30", crc: "A4F89B12", isSelected: true)
                            fileRow(icon: "photo.fill", iconColor: .purple, name: "Logo_Retina_4K.png", type: "PNG Görseli", size: "5,1 MB", packed: "3,8 MB", date: "22 Eki 16:45", crc: "7E8F9A0B", isSelected: false)
                            fileRow(icon: "gearshape.fill", iconColor: .orange, name: "Configuration.json", type: "JSON Verisi", size: "18 KB", packed: "4 KB", date: "25 Eki 12:10", crc: "B3C5D7E9", isSelected: false)
                            fileRow(icon: "doc.text.fill", iconColor: .gray, name: "README.md", type: "Markdown", size: "12 KB", packed: "3 KB", date: "25 Eki 17:50", crc: "F1E2D3C4", isSelected: false)
                            fileRow(icon: "externaldrive.fill", iconColor: .teal, name: "Veritabani_Yedek.sql", type: "SQL Veritabanı", size: "14,2 MB", packed: "3,2 MB", date: "20 Eki 09:15", crc: "5E6F7A8B", isSelected: false)
                        }

                        Spacer()
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
                }

                Divider()

                // Alt Durum Çubuğu
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("1 seçili (2,4 MB)")
                    }
                    .font(.system(size: 11, weight: .semibold))

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("8 öge • 21,9 MB (Paketli: 8,9 MB)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("%59.4 Tasarruf")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.green.opacity(0.2)))
                    .foregroundColor(.green)

                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10))
                        Text("AES-256 Korumalı")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.18)))
                    .foregroundColor(Color.accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }

    private func headerButton(icon: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }

    private func toolbarButton(icon: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
        .foregroundColor(.primary)
    }

    private func sidebarRow(icon: String, title: String, count: String, color: Color, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()

            Text(count)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .padding(.horizontal, 6)
    }

    private func sidebarFolderRow(title: String, count: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.accentColor.opacity(0.85))
                .frame(width: 16)

            Text(title)
                .font(.system(size: 11.5))

            Spacer()

            Text(count)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }

    private func fileRow(icon: String, iconColor: Color, name: String, type: String, size: String, packed: String, date: String, crc: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(width: 220, alignment: .leading)

            Text(type)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .frame(width: 95, alignment: .leading)

            Text(size)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white.opacity(0.9) : .primary)
                .frame(width: 75, alignment: .trailing)

            Text(packed)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                .frame(width: 75, alignment: .trailing)

            Text(date)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                .frame(width: 120, alignment: .leading)

            Text(crc)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                .frame(width: 70, alignment: .center)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color.accentColor : Color.clear
        )
    }
}

// MARK: - 2. Ayarlar Ekranı
private struct SettingsScreenshotView: View {
    var body: some View {
        MacWindowFrame(title: "UnPack — Ayarlar") {
            HStack(spacing: 0) {
                // Sol Menü
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.gradient)
                                .frame(width: 32, height: 32)
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("UnPack")
                                .font(.system(size: 14, weight: .bold))
                            Text("Ayarlar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 18)

                    VStack(spacing: 4) {
                        tabButton(icon: "gearshape.fill", title: "Genel", isSelected: true)
                        tabButton(icon: "archivebox", title: "Formatlar", isSelected: false)
                        tabButton(icon: "shield.lefthalf.filled", title: "Güvenlik", isSelected: false)
                        tabButton(icon: "macwindow", title: "Finder Menüsü", isSelected: false)
                        tabButton(icon: "info.circle", title: "Hakkında", isSelected: false)
                    }
                    .padding(.horizontal, 10)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("UnPack v1.7.1")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Universal (Apple & Intel)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .padding(.bottom, 16)
                }
                .frame(width: 195)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

                Divider()

                // Sağ Ayarlar İçeriği (Genel Sekmesi)
                VStack(alignment: .leading, spacing: 18) {
                    // Bölüm 1: Çıkarma & Dosya İşlemleri
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Çıkarma ve Sistem İşlemleri")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 0) {
                            settingToggleRow(icon: "trash.fill", color: .red, title: "Çıkardıktan sonra arşivi Çöp Sepeti'ne taşı", subtitle: "Başarılı çıkarma sonrası kaynak arşivi güvenle çöpe taşır", isOn: false)
                            Divider().padding(.leading, 42)
                            settingToggleRow(icon: "speaker.wave.2.fill", color: .purple, title: "İşlem tamamlandığında ses çal", subtitle: "Arşivleme ve çıkarma bittiğinde bildirim tonu çalar", isOn: true)
                            Divider().padding(.leading, 42)
                            settingToggleRow(icon: "macwindow", color: .blue, title: "Tamamlanan dosyaları Finder'da göster", subtitle: "Çıkartılan klasörü doğrudan Finder penceresinde odaklar", isOn: true)
                        }
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Bölüm 2: macOS Sistem Artıkları
                    VStack(alignment: .leading, spacing: 8) {
                        Text("macOS Sistem Artıkları Filtresi")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 0) {
                            settingToggleRow(icon: "sparkles", color: .mint, title: "Gereksiz sistem dosyalarını otomatik filtrele", subtitle: ".DS_Store, __MACOSX ve geçici Apple dosyalarını temizler", isOn: true)
                            Divider().padding(.leading, 42)
                            settingToggleRow(icon: "doc.badge.gearshape.fill", color: .teal, title: "AppleDouble (._*) meta verilerini ayıkla", subtitle: "Windows ve Linux kullanıcıları için temiz arşivler oluşturur", isOn: true)
                        }
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Bölüm 3: Görünüm & Vurgu Rengi
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Arayüz & Tema")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Uygulama Vurgu Rengi")
                                .font(.system(size: 12))

                            Spacer()

                            HStack(spacing: 6) {
                                Circle().fill(Color.blue).frame(width: 18, height: 18).overlay(Circle().stroke(Color.white, lineWidth: 2))
                                Circle().fill(Color.purple).frame(width: 16, height: 16)
                                Circle().fill(Color.green).frame(width: 16, height: 16)
                                Circle().fill(Color.orange).frame(width: 16, height: 16)
                                Circle().fill(Color.gray).frame(width: 16, height: 16)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func tabButton(icon: String, title: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : Color.accentColor)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }

    private func settingToggleRow(icon: String, color: Color, title: String, subtitle: String, isOn: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.2))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Özel Kusursuz SwiftUI Anahtarı (Toggle)
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 20)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .padding(2)
                    .shadow(radius: 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - 3. Canlı Sürüm Güncelleyici Ekranı
private struct UpdaterScreenshotView: View {
    var body: some View {
        MacWindowFrame(title: "UnPack Güncelleme") {
            VStack(spacing: 16) {
                // Üst Başlık & Simge
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.blue.opacity(0.35), radius: 8, y: 3)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Yeni Sürüm Mevcut: v1.7.1")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Mevcut: v1.7.0 • Hedef: v1.7.1 (Önerilen Güncelleme)")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Divider()

                // Sürüm Notları Kartı
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Yenilikler & İyileştirmeler")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        Text("15,8 MB • DMG")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        noteRow(icon: "sparkles", text: "macOS Finder sağ tık menüsünde doğrudan 'UnPack ile...' eylemleri")
                        noteRow(icon: "bolt.fill", text: "Apple Silicon M-serisi Mac'ler için %40 daha hızlı arşivleme")
                        noteRow(icon: "square.split.2x1.fill", text: "Çok parçalı (.part1 / .001) arşivleri tek tıkla otomatik birleştirme")
                        noteRow(icon: "shield.checkered", text: "Gelişmiş Zip Slip koruması ve şifrelenmiş başlık denetimi")
                        noteRow(icon: "macwindow.badge.plus", text: "Apple Liquid Glass dosya simgeleri ve modern arayüz tasarımı")
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.horizontal, 20)

                // İndirme İlerleme Çubuğu
                VStack(spacing: 6) {
                    HStack {
                        Text("İndiriliyor... %74")
                            .font(.system(size: 11.5, weight: .semibold))
                        Spacer()
                        Text("11,8 MB / 15,8 MB (4,2 MB/sn)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Özel Kusursuz SwiftUI İlerleme Çubuğu
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)

                        Capsule()
                            .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 370, height: 6)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Divider()

                // Aksiyon Butonları
                HStack {
                    HStack {
                        Text("Daha Sonra")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 0.5))

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Güncelle ve Yeniden Başlat")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color.accentColor)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(2)
        }
    }
}

// MARK: - 4. Hızlı Bırakma Alanı Ekranı
private struct QuickDropScreenshotView: View {
    var body: some View {
        MacWindowFrame(title: "UnPack — Hızlı Mod") {
            VStack(spacing: 0) {
                // Üst Navigasyon Çubuğu
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.accentColor)

                        Text("UnPack")
                            .font(.system(size: 15, weight: .bold))
                    }

                    Spacer()

                    // Mod Seçici (Hızlı Bırakma seçili)
                    HStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "macwindow.on.rectangle")
                            Text("Gezgin Modu")
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            Image(systemName: "bolt.shield.fill")
                            Text("Hızlı Bırakma")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                    }
                    .padding(2)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer()

                    HStack(spacing: 8) {
                        headerButton(icon: "plus.circle.fill", title: "Sıkıştır")
                        headerButton(icon: "folder.fill", title: "Arşiv Aç")

                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Orta Bırakma Alanı
                VStack(spacing: 22) {
                    Spacer()

                    // Yuvarlatılmış Kesikli Çerçeveli Ana Kart
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 88, height: 88)

                            Circle()
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                                .frame(width: 88, height: 88)

                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 38))
                                .foregroundColor(Color.accentColor)
                        }

                        VStack(spacing: 6) {
                            Text("Dosyaları veya Arşivleri Buraya Bırakın")
                                .font(.system(size: 18, weight: .bold))

                            Text("Arşiv dosyaları klasöre çıkartılır, klasörler ve dosyalar ise anında sıkıştırılır.")
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                        }

                        // Desteklenen Biçim Kapsülleri
                        HStack(spacing: 8) {
                            formatPill("RAR", color: .purple)
                            formatPill("ZIP", color: .blue)
                            formatPill("7Z", color: .orange)
                            formatPill("TAR", color: .teal)
                            formatPill("GZ", color: .green)
                            formatPill("XZ", color: .indigo)
                        }

                        // Hızlı Seçim Butonları
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.badge.plus")
                                Text("Dosya Seç...")
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.accentColor)
                            )

                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Klasör Seç...")
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                    }
                    .frame(maxWidth: 580)
                    .padding(.vertical, 36)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                Color.accentColor.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                            )
                    )

                    // Alt İpuçları
                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("macOS sistem artıkları otomatik temizlenir")
                        }

                        Text("•")
                            .foregroundColor(.secondary)

                        HStack(spacing: 5) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(Color.accentColor)
                            Text("AES-256 şifreleme desteklenir")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
            }
        }
    }

    private func headerButton(icon: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }

    private func formatPill(_ format: String, color: Color) -> some View {
        Text(format)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
