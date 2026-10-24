import SwiftUI
import FinderSync

@MainActor
private final class SettingsViewState: ObservableObject {
    @Published var activeTab: SettingsTab = .general
    @Published var feedbackMessage: String? = nil
}

/// Modernize edilmiş Coffer Ayarlar Penceresi
@MainActor
public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var viewState = SettingsViewState()
    @Binding public var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Sol Kenar Çubuğu (Sidebar)
            VStack(spacing: 0) {
                // Başlık & Logo
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(settings.accentColorChoice.color.gradient)
                            .frame(width: 32, height: 32)
                            .shadow(color: settings.accentColorChoice.color.opacity(0.3), radius: 4, y: 2)

                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Coffer")
                            .font(.system(size: 15, weight: .bold))
                        Text("Tercihler")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Sekme Butonları Listesi
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        SidebarTabButton(
                            tab: tab,
                            isSelected: viewState.activeTab == tab,
                            accentColor: settings.accentColorChoice.color,
                            onSelect: {
                                withAnimation(settings.enableAnimations ? .spring(response: 0.25, dampingFraction: 0.8) : nil) {
                                    viewState.activeTab = tab
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                // Sol Alt Sürüm Rozeti
                VStack(spacing: 2) {
                    Text("Coffer v1.3.0")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("Universal (Apple & Intel)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            }
            .frame(width: 195)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            // Dikey İnce Ayırıcı Çizgi
            Rectangle()
                .fill(Color(NSColor.separatorColor).opacity(0.4))
                .frame(width: 1)

            // Sağ İçerik Alanı
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Sekme Başlığı
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: viewState.activeTab.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(viewState.activeTab.iconColor)

                                Text(viewState.activeTab.title)
                                    .font(.system(size: 18, weight: .bold))
                            }

                            Text(viewState.activeTab.subtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 4)

                        // Aktif Sekme Görünümü
                        switch viewState.activeTab {
                        case .general:
                            GeneralSettingsPane(settings: settings)
                        case .appearance:
                            AppearanceSettingsPane(settings: settings)
                        case .compression:
                            CompressionSettingsPane(settings: settings)
                        case .extraction:
                            ExtractionSettingsPane(settings: settings)
                        case .finder:
                            FinderSettingsPane(
                                isPresented: $isPresented,
                                onShowFeedback: { msg in
                                    withAnimation {
                                        viewState.feedbackMessage = msg
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        withAnimation {
                                            viewState.feedbackMessage = nil
                                        }
                                    }
                                }
                            )
                        case .about:
                            AboutSettingsPane(isPresented: $isPresented)
                        }
                    }
                    .padding(24)
                }

                // Alt Çubuk (Footer Bar)
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.5)

                    HStack {
                        if let msg = viewState.feedbackMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(msg)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .transition(.opacity)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("Değişiklikler anında otomatik uygulanır")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button("Tamam") {
                            isPresented = false
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                }
            }
        }
        .frame(width: 710, height: 590)
        .tint(settings.accentColorChoice.color)
        .accentColor(settings.accentColorChoice.color)
    }
}

// MARK: - Sekme Tanımları
private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Genel"
    case appearance = "Görünüm"
    case compression = "Sıkıştırma"
    case extraction = "Akıllı Çıkarma"
    case finder = "Finder & Servisler"
    case about = "Hakkında"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .general:
            return "Otomasyon, dosya yönetimi ve bildirim tercihleri."
        case .appearance:
            return "Tema görünümü, arayüz vurgu renkleri ve görsel derinlik efektleri."
        case .compression:
            return "Varsayılan arşivleme formatı, sıkıştırma oranı ve performans simülatörü."
        case .extraction:
            return "Klasör bombası koruması, akıllı çıkarma kuralları ve hedef konumlar."
        case .finder:
            return "macOS Finder sağ tık doğrudan menü entegrasyonu ve dosya uzantısı eşlemeleri."
        case .about:
            return "Coffer sürüm detayları, motor mimarisi ve lisans bilgileri."
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .compression: return "archivebox.fill"
        case .extraction: return "bolt.shield.fill"
        case .finder: return "macwindow.badge.plus"
        case .about: return "info.circle.fill"
        }
    }

    func dynamicIconColor(accentColor: Color) -> Color {
        switch self {
        case .general: return .blue
        case .appearance: return .purple
        case .compression: return accentColor
        case .extraction: return .green
        case .finder: return .cyan
        case .about: return .indigo
        }
    }

    var iconColor: Color {
        dynamicIconColor(accentColor: AppSettings.shared.accentColorChoice.color)
    }
}

// MARK: - Sol Kenar Çubuğu Butonu
@MainActor
private struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let accentColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Renkli Squircle İkon
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tab.dynamicIconColor(accentColor: accentColor).gradient)
                        .frame(width: 24, height: 24)

                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? accentColor
                            : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 1. Genel Ayarlar Paneli
private struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            // Otomasyon ve Bildirimler Kartı
            SettingsCard(title: "Otomasyon & Bildirimler") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "speaker.wave.2.fill",
                        iconColor: .blue,
                        title: "İşlem Tamamlandığında Ses Çal",
                        subtitle: "Arşivleme veya çıkartma işlemi bittiğinde bildirim sesi çalar."
                    ) {
                        Toggle("", isOn: $settings.playSoundOnCompletion)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "folder.badge.gearshape",
                        iconColor: .cyan,
                        title: "Hedef Klasörü Finder'da Aç",
                        subtitle: "Çıkartma veya sıkıştırma tamamlandığında oluşan klasörü Finder'da öne çıkarır."
                    ) {
                        Toggle("", isOn: $settings.revealInFinderAfterExtract)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: "Orijinal Arşivi Çöp Sepeti'ne Taşı",
                        subtitle: "Çıkartma başarılı olduğunda kaynak arşivi otomatik olarak Çöp Sepeti'ne gönderir."
                    ) {
                        Toggle("", isOn: $settings.trashArchiveAfterExtract)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }

            // Dosya Yönetimi ve Temizlik Kartı
            SettingsCard(title: "Dosya İşlemleri ve Sistem Temizliği") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "doc.on.doc.fill",
                        iconColor: .indigo,
                        title: "Mevcut Dosyaların Üzerine Otomatik Yaz",
                        subtitle: "Çıkartılan dosyalar hedefte zaten varsa sormadan güncel dosyayla değiştirir."
                    ) {
                        Toggle("", isOn: $settings.overwriteExistingFiles)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "applelogo",
                        iconColor: .gray,
                        title: "macOS Sistem Artıklarını Temizle",
                        subtitle: "Arşiv oluştururken ve açarken .DS_Store, __MACOSX ve AppleDouble özniteliklerini eler."
                    ) {
                        Toggle("", isOn: $settings.stripMacJunkFiles)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
        }
    }
}

// MARK: - 2. Görünüm Ayarları Paneli
private struct AppearanceSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            // Tema Kartı
            SettingsCard(title: "Uygulama Teması") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        ForEach(AppSettings.AppTheme.allCases) { theme in
                            ThemeSelectionCard(
                                theme: theme,
                                isSelected: settings.selectedTheme == theme,
                                accentColor: settings.accentColorChoice.color,
                                onSelect: {
                                    withAnimation(settings.enableAnimations ? .spring(response: 0.25) : nil) {
                                        settings.selectedTheme = theme
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(14)
            }

            // Vurgu Rengi Paleti Kartı
            SettingsCard(title: "Buton ve Vurgu Rengi") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Aktif Renk:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(settings.accentColorChoice.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(settings.accentColorChoice.color)
                        Spacer()
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                        ForEach(AppSettings.AppAccentColor.allCases) { accent in
                            ModernAccentColorItem(
                                accent: accent,
                                isSelected: settings.accentColorChoice == accent,
                                onSelect: {
                                    withAnimation(settings.enableAnimations ? .spring(response: 0.3) : nil) {
                                        settings.accentColorChoice = accent
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(14)
            }

            // Animasyon ve Görsel Efektler Kartı
            SettingsCard(title: "Arayüz ve Görsel Efektler") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "sparkles",
                        iconColor: settings.accentColorChoice.color,
                        title: "Akıcı Arayüz Animasyonları",
                        subtitle: "Pencere geçişleri, diyalog açılışları ve buton etkileşim efektleri."
                    ) {
                        Toggle("", isOn: $settings.enableAnimations)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "cube.transparent.fill",
                        iconColor: .purple,
                        title: "3D Derinlik ve Eğim Efekti",
                        subtitle: "İmleç pozisyonuna göre pencere ve butonlara hafif jiroskopik perspektif kazandırır."
                    ) {
                        Toggle("", isOn: $settings.enable3DDepthTilt)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "menubar.rectangle",
                        iconColor: .blue,
                        title: "Menü Çubuğu (Menu Bar) Hızlı Sürükle-Bırak Alanı",
                        subtitle: "macOS üst menü çubuğuna doğrudan arşiv oluşturup açabileceğiniz Coffer simgesi ekler."
                    ) {
                        Toggle("", isOn: $settings.enableMenuBarDropZone)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
        }
    }
}

// MARK: - 3. Sıkıştırma Ayarları Paneli
private struct CompressionSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            // Varsayılan Format ve Seviye
            SettingsCard(title: "Varsayılan Sıkıştırma Parametreleri") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "doc.zipper",
                        iconColor: settings.accentColorChoice.color,
                        title: "Varsayılan Arşiv Formatı",
                        subtitle: "Hızlı arşivleme işlemlerinde varsayılan olarak tercih edilen dosya uzantısı."
                    ) {
                        Picker("", selection: $settings.defaultFormat) {
                            Text("ZIP (Evrensel)").tag("ZIP")
                            Text("TAR.GZ (Hızlı Linux/Mac)").tag("TAR.GZ")
                            Text("TAR.BZ2 (Yüksek Sıkıştırma)").tag("TAR.BZ2")
                            Text("TAR.XZ (Maksimum)").tag("TAR.XZ")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 175)
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "slider.horizontal.3",
                        iconColor: .indigo,
                        title: "Varsayılan Sıkıştırma Seviyesi",
                        subtitle: "İşlem hızı ile dosya boyutu arasındaki dengeyi belirler."
                    ) {
                        Picker("", selection: $settings.defaultCompressionLevel) {
                            Text("0 - Depola (Sıfır Sıkıştırma)").tag(0)
                            Text("1 - En Hızlı").tag(1)
                            Text("3 - Hızlı").tag(3)
                            Text("5 - Normal (Dengeli)").tag(5)
                            Text("7 - İyi").tag(7)
                            Text("9 - En İyi (Maksimum)").tag(9)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 175)
                    }
                }
            }

            // Simülatör ve Gelişmiş Filtreler
            SettingsCard(title: "Simülatör & Gelişmiş Ayarlar") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .green,
                        title: "Canlı Boyut & Süre Simülatörü",
                        subtitle: "Sıkıştırma penceresinde seçilen formata göre tahmini disk alanı tasarrufunu gösterir."
                    ) {
                        Toggle("", isOn: $settings.enableSizeSimulator)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    CardRowDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Temiz Arşiv Garantisi")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                        }

                        Text("Coffer ile oluşturulan arşivlerde gizli macOS sistem çöpleri (.DS_Store, __MACOSX meta verileri) otomatik elenir. Böylece arşivleriniz Windows ve Linux ortamlarında tertemiz açılır.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(14)
                }
            }
        }
    }
}

// MARK: - 4. Akıllı Çıkarma Ayarları Paneli
private struct ExtractionSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            // Klasör Bombası Koruması
            SettingsCard(title: "Akıllı Çıkarma (Klasör Bombası Koruması)") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "shield.lefthalf.filled.badge.checkmark",
                        iconColor: .green,
                        title: "Klasör Bombası Korumasını Etkinleştir",
                        subtitle: "Masaüstünüzün ve klasörlerinizin binlerce dağınık dosya ile dolmasını engeller."
                    ) {
                        Toggle("", isOn: $settings.enableSmartExtraction)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    CardRowDivider()

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.max.fill")
                            .font(.system(size: 16))
                            .foregroundColor(settings.accentColorChoice.color)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Akıllı Çıkarma Nasıl Çalışır?")
                                .font(.system(size: 12, weight: .semibold))

                            Text("İçerisinde tek bir ana klasör bulunmayan ve doğrudan kök dizine yayılmış çok sayıda dosya barındıran arşivler tespit edildiğinde; Coffer otomatik olarak arşiv adında yeni bir klasör açar ve dosyaları o klasörün içine güvenle çıkartır.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                    }
                    .padding(14)
                }
            }

            // Varsayılan Hedef Konum
            SettingsCard(title: "Hedef Çıkarma Konumu") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "shippingbox.and.arrow.backward.fill",
                        iconColor: .blue,
                        title: "Varsayılan Çıkarma Konumu",
                        subtitle: "Hızlı çıkartma yapıldığında dosyaların yerleştirileceği klasör."
                    ) {
                        Picker("", selection: $settings.defaultExtractLocation) {
                            Text("Arşiv ile Aynı Klasör").tag("sameFolder")
                            Text("Masaüstü (~/Desktop)").tag("desktop")
                            Text("İndirilenler (~/Downloads)").tag("downloads")
                            Text("Her Seferinde Sor").tag("ask")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 175)
                    }
                }
            }
        }
    }
}

// MARK: - 5. Finder ve Servisler Paneli
private struct FinderSettingsPane: View {
    @ObservedObject private var settings = AppSettings.shared
    @Binding var isPresented: Bool
    let onShowFeedback: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Sağ Tık Menü Önizlemesi Kartı
            SettingsCard(title: "Finder Sağ Tık Entegrasyonu (WinRAR Tarzı)") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Finder'da herhangi bir arşive veya dosyaya sağ tıkladığınızda alt menülerde kaybolmadan doğrudan ana menüde seçenekler sunulur:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    // Finder Menü Önizleme Görseli
                    VStack(alignment: .leading, spacing: 6) {
                        FinderMockMenuItem(icon: "arrow.down.doc.fill", title: "Coffer ▶ Buraya Çıkart", iconColor: .blue)
                        FinderMockMenuItem(icon: "folder.badge.plus", title: "Coffer ▶ \"[Arşiv Adı]\" Adıyla Klasöre Çıkart", iconColor: .green)
                        FinderMockMenuItem(icon: "doc.zipper", title: "Coffer ▶ \"[Dosya Adı].zip\" Olarak Sıkıştır", iconColor: settings.accentColorChoice.color)
                        FinderMockMenuItem(icon: "slider.horizontal.3", title: "Coffer ▶ Coffer ile Sıkıştır... (Gelişmiş)", iconColor: .purple)
                        FinderMockMenuItem(icon: "macwindow.on.rectangle", title: "Coffer ▶ Coffer ile Aç ve Gözat", iconColor: .cyan)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(14)
            }

            // Sistem Eşitleme ve Hızlı Eylemler Kartı
            SettingsCard(title: "Sistem ve Finder Senkronizasyonu") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "checklist",
                        iconColor: .blue,
                        title: "Finder Eklentisi Ayarları",
                        subtitle: "macOS Sistem Ayarları altındaki Finder Uzantıları yönetimini açar."
                    ) {
                        Button("Uzantıyı Yönet") {
                            FIFinderSyncController.showExtensionManagementInterface()
                            onShowFeedback("Finder uzantı paneli açıldı.")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "archivebox.fill",
                        iconColor: settings.accentColorChoice.color,
                        title: "Dosya İkonlarını Eşitle & Yenile",
                        subtitle: "RAR, ZIP, 7Z, TAR uzantılarını Coffer'a bağlar ve QuickLook önbelleğini temizler."
                    ) {
                        Button("İkonları Eşitle") {
                            DefaultAppManager.shared.registerAsDefaultArchiveHandler()
                            onShowFeedback("Dosya ikonları ve önbellek başarıyla yenilendi.")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .green,
                        title: "Finder Servislerini Yenile",
                        subtitle: "macOS dinamik sağ tık servislerini anında yeniden yükler."
                    ) {
                        Button("Servisleri Yenile") {
                            CofferServicesProvider.shared.registerFinderServices()
                            onShowFeedback("Finder servisleri anında tazelendi.")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }
        }
    }
}

// MARK: - 6. Hakkında Paneli
private struct AboutSettingsPane: View {
    @Binding var isPresented: Bool
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var showReleaseNotesSheet: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            // Logo ve Başlık
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.purple.opacity(0.35), radius: 12, y: 5)

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 4) {
                    Text("Coffer")
                        .font(.system(size: 22, weight: .bold))
                    Text("Sürüm \(updateChecker.currentVersion) (Universal)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Text("macOS için Ultra Hızlı, Güvenli ve Akıllı Arşivleme Yöneticisi")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            // Güncelleme & GitHub Yayınları Kartı
            SettingsCard(title: "Yazılım Güncelleme & GitHub") {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .blue,
                        title: "Güncellemeleri Denetle",
                        subtitle: updateChecker.lastCheckStatus ?? "GitHub Releases üzerinden yeni sürümleri denetler."
                    ) {
                        Button {
                            Task {
                                await updateChecker.checkForUpdates(manual: true)
                            }
                        } label: {
                            if updateChecker.isChecking {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Denetleniyor...")
                                }
                            } else {
                                Label("Güncellemeleri Denetle", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(updateChecker.isChecking)
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "link",
                        iconColor: .purple,
                        title: "GitHub Deposu",
                        subtitle: "github.com/\(updateChecker.repoSlug)"
                    ) {
                        Button("GitHub'da Aç") {
                            if let url = URL(string: "https://github.com/\(updateChecker.repoSlug)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    CardRowDivider()

                    SettingsRow(
                        icon: "sparkles",
                        iconColor: .orange,
                        title: "Sürüm Notları & Yenilikler",
                        subtitle: "v\(updateChecker.currentVersion) ile gelen tüm yeni özellik ve optimizasyonlar"
                    ) {
                        Button("Yenilikleri Gör") {
                            showReleaseNotesSheet = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }

            // Mimari ve Teknik Özellikler Kartı
            SettingsCard(title: "Motor & Sistem Mimarisi") {
                VStack(spacing: 0) {
                    InfoDetailRow(title: "Arşiv Motoru", value: "7-Zip Core + libarchive Native Engine")
                    CardRowDivider()
                    InfoDetailRow(title: "Desteklenen Biçimler", value: "RAR, ZIP, 7Z, TAR, GZ, BZ2, XZ, ISO, CAB, WIM")
                    CardRowDivider()
                    InfoDetailRow(title: "Şifreleme Desteği", value: "AES-256 Bit Askeri Standart & Başlık Gizleme")
                    CardRowDivider()
                    InfoDetailRow(title: "İşlemci Desteği", value: "Apple Silicon (M1/M2/M3/M4) + Intel 64-bit")
                    CardRowDivider()
                    InfoDetailRow(title: "Gizlilik & Güvenlik", value: "%100 Çevrimdışı, Sıfır Telemetri")
                }
            }

            // Telif Hakkı ve Bildirim
            VStack(spacing: 4) {
                Text("Tüm hakları saklıdır. macOS Sonoma & Sequoia ile tam uyumludur.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .sheet(isPresented: $showReleaseNotesSheet) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange.gradient)
                            .frame(width: 36, height: 36)

                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coffer Yenilikler & Sürüm Notları")
                            .font(.system(size: 15, weight: .bold))
                        Text("Coffer v\(updateChecker.currentVersion) Sürüm Detayları")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Tamam") {
                        showReleaseNotesSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Divider()

                ReleaseNotesMarkdownView(markdown: currentReleaseNotes)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(width: 540, height: 480)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    private var currentReleaseNotes: String {
        if let body = UpdateDownloadManager.shared.releaseInfo?.body, !body.isEmpty {
            return body
        }
        return """
        ## 🚀 Coffer v1.3.0 (En Son Sürüm)

        Coffer'ın yeni sürümü; yenilenen sol kenar çubuğu tasarımı, yüksek performans optimizasyonları ve Apple standartlarında görsel geliştirmelerle kullanıma sunuldu.

        ### ✨ Yenilikler ve İyileştirmeler

        - 📂 **Yenilenen Sol Kenar Çubuğu:** Sıkıştırılmış arşiv açıldığında sol tarafta yer alan klasör konumu, akıllı filtreler ve klasör ağacı Apple tasarım çizgilerine uygun şekilde baştan tasarlandı.
        - ⚡ **Yüksek Hız ve Sıfır Takılma:** Çok sayıda dosya ve klasör içeren büyük arşivlerde gezinirken yaşanan bekleme ve donmalar tamamen giderildi. Önbellekleme mimarisi sayesinde tüm klasör geçişleri anında gerçekleşir.
        - 🎯 **Akıllı Kategori Filtreleri:** Arşiv içindeki görseller, belgeler, medya dosyaları ve kodlar renkli Apple simgeleriyle gruplandırıldı. Aradığınız dosya türüne tek bir tıklamayla ulaşabilirsiniz.
        - 🌀 **Animasyonlu İlerleme Ekranı:** Arşiv oluşturma ve çıkarma ekranları; dönen yörünge halkası, canlı hız göstergesi ve kalan süre sayacı ile donatıldı.
        - 📝 **Zengin Sürüm Notları:** Yeni özellikler ve değişiklikler, tüm detaylarıyla anlaşılır kartlar halinde sunulmaktadır.
        - 🛡️ **Kolay Kurulum Sihirbazı:** Uygulama ilk kez açıldığında gerekli macOS sistem izinleri tek tıkla otomatik olarak tanımlanır.

        ### 📦 Sistem Uyumluluğu
        - **Evrensel Destek:** Apple Silicon (M1, M2, M3, M4) ve Intel (x86_64) işlemcili Mac bilgisayarlarla tam uyumludur.
        - **İşletim Sistemi:** macOS Sonoma (14.0) ve macOS Sequoia (15.0) sürümlerini destekler.
        """
    }
}

// MARK: - Yardımcı Arayüz Bileşenleri (Reusable Components)

/// Modern macOS System Settings Tarzı Gruplanmış Kart
private struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
        }
    }
}

/// Standart Ayar Satırı
private struct SettingsRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let control: Control

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Renkli Squircle İkon
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor.gradient)
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Metinler
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            // Sağ Kontrol
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Kart içi ince satır ayırıcı
private struct CardRowDivider: View {
    var body: some View {
        Divider()
            .opacity(0.35)
            .padding(.leading, 52)
    }
}

/// Finder Sağ Tık Mock Satırı
private struct FinderMockMenuItem: View {
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

/// Hakkında detay satırı
private struct InfoDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Görsel Tema Seçim Kartı
@MainActor
private struct ThemeSelectionCard: View {
    let theme: AppSettings.AppTheme
    let isSelected: Bool
    let accentColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Önizleme Penceresi Görseli
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(themePreviewBackground)
                        .frame(height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? accentColor : Color(NSColor.separatorColor).opacity(0.4), lineWidth: isSelected ? 2 : 1)
                        )

                    // Mini Arayüz Elemanları
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 6, height: 6)
                            Circle().fill(Color.yellow.opacity(0.8)).frame(width: 6, height: 6)
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 6, height: 6)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(themeSidebarColor)
                                .frame(width: 22, height: 34)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(themeContentColor)
                                .frame(height: 34)
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                    }

                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(accentColor)
                                    .background(Circle().fill(Color.white).padding(1))
                            }
                            Spacer()
                        }
                        .padding(4)
                    }
                }

                Text(theme.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var themePreviewBackground: Color {
        switch theme {
        case .light:
            return Color(white: 0.96)
        case .dark:
            return Color(white: 0.16)
        case .system:
            return Color(NSColor.windowBackgroundColor)
        }
    }

    private var themeSidebarColor: Color {
        switch theme {
        case .light:
            return Color(white: 0.88)
        case .dark:
            return Color(white: 0.24)
        case .system:
            return Color.primary.opacity(0.12)
        }
    }

    private var themeContentColor: Color {
        switch theme {
        case .light:
            return Color.white
        case .dark:
            return Color(white: 0.10)
        case .system:
            return Color.primary.opacity(0.08)
        }
    }
}

/// Modernize Edilmiş Vurgu Rengi Seçim Butonu
@MainActor
private struct ModernAccentColorItem: View {
    let accent: AppSettings.AppAccentColor
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(accent.color.gradient)
                        .frame(width: 28, height: 28)
                        .shadow(color: accent.color.opacity(isSelected ? 0.5 : 0.2), radius: isSelected ? 5 : 2, y: 1)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? accent.color : Color.clear, lineWidth: 2)
                        .frame(width: 36, height: 36)
                )

                Text(accent.rawValue)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help(accent.rawValue)
    }
}
