import SwiftUI
import AppKit
import UniformTypeIdentifiers
import UserNotifications
import FinderSync

@MainActor
private final class OnboardingStepState: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var isApplying: Bool = false
    @Published var progressMessage: String = "Yapılandırma uygulanıyor..."

    @Published var isInstallToApplicationsSelected: Bool = true
    @Published var isDefaultAppSelected: Bool = true
    @Published var isFinderIntegrationSelected: Bool = true
    @Published var isNotificationsSelected: Bool = true
    @Published var isCleanJunkSelected: Bool = true

    @Published var hasNotificationPermission: Bool = false
    @Published var hasDiskAccessPermission: Bool = false
    @Published var isFinderExtensionActive: Bool = false

    @Published var checkmarkScale: CGFloat = 0.3
    @Published var checkmarkOpacity: Double = 0.0
}

/// macOS standartlarına uygun UnPack İlk Kurulum ve İzin Yönetimi
@MainActor
public struct OnboardingWizardView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var stepState = OnboardingStepState()
    @Binding public var isPresented: Bool

    private var currentStep: Int {
        get { stepState.currentStep }
        nonmutating set { stepState.currentStep = newValue }
    }
    private var isApplying: Bool {
        get { stepState.isApplying }
        nonmutating set { stepState.isApplying = newValue }
    }
    private var progressMessage: String {
        get { stepState.progressMessage }
        nonmutating set { stepState.progressMessage = newValue }
    }
    private var isInstallToApplicationsSelected: Bool {
        get { stepState.isInstallToApplicationsSelected }
        nonmutating set { stepState.isInstallToApplicationsSelected = newValue }
    }
    private var isDefaultAppSelected: Bool {
        get { stepState.isDefaultAppSelected }
        nonmutating set { stepState.isDefaultAppSelected = newValue }
    }
    private var isFinderIntegrationSelected: Bool {
        get { stepState.isFinderIntegrationSelected }
        nonmutating set { stepState.isFinderIntegrationSelected = newValue }
    }
    private var isNotificationsSelected: Bool {
        get { stepState.isNotificationsSelected }
        nonmutating set { stepState.isNotificationsSelected = newValue }
    }
    private var isCleanJunkSelected: Bool {
        get { stepState.isCleanJunkSelected }
        nonmutating set { stepState.isCleanJunkSelected = newValue }
    }
    private var hasNotificationPermission: Bool {
        get { stepState.hasNotificationPermission }
        nonmutating set { stepState.hasNotificationPermission = newValue }
    }
    private var hasDiskAccessPermission: Bool {
        get { stepState.hasDiskAccessPermission }
        nonmutating set { stepState.hasDiskAccessPermission = newValue }
    }
    private var isFinderExtensionActive: Bool {
        get { stepState.isFinderExtensionActive }
        nonmutating set { stepState.isFinderExtensionActive = newValue }
    }
    private var checkmarkScale: CGFloat {
        get { stepState.checkmarkScale }
        nonmutating set { stepState.checkmarkScale = newValue }
    }
    private var checkmarkOpacity: Double {
        get { stepState.checkmarkOpacity }
        nonmutating set { stepState.checkmarkOpacity = newValue }
    }

    /// Uygulamanın /Applications dizini dışından (örneğin DMG veya İndirilenler) çalışıp çalışmadığını kontrol eder
    private var isRunningOutsideApplications: Bool {
        let path = Bundle.main.bundleURL.path
        return !path.hasPrefix("/Applications")
    }

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Üst Navigasyon & Adım Göstergesi & Hızlı Kontroller
            topHeaderBar
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .opacity(0.35)

            // Ana İçerik (Kaydırılabilir & Esnek Ölçekli)
            ZStack {
                switch currentStep {
                case 0:
                    welcomeStepView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case 1:
                    configurationStepView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case 2:
                    permissionsStepView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                default:
                    completionStepView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Divider()
                .opacity(0.35)

            // Alt Aksiyon Butonları
            bottomActionBar
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        }
        .frame(maxWidth: 580, maxHeight: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 12)
        .tint(settings.accentColorChoice.color)
    }

    // MARK: - Üst Bar: Adım Göstergesi (Ortalanmış, Sade ve Net)

    private var topHeaderBar: some View {
        HStack {
            Color.clear.frame(width: 24, height: 24)

            Spacer()
            stepIndicatorHeader
            Spacer()

            Button(action: {
                settings.hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                UserDefaults.standard.synchronize()
                withAnimation(.spring(response: 0.35)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Kapat")
        }
    }

    private var stepIndicatorHeader: some View {
        HStack(spacing: 10) {
            stepBadge(index: 0, title: "Başlangıç")
            stepConnector(active: currentStep >= 1)
            stepBadge(index: 1, title: "Yapılandırma")
            stepConnector(active: currentStep >= 2)
            stepBadge(index: 2, title: "İzinler")
            stepConnector(active: currentStep >= 3)
            stepBadge(index: 3, title: "Hazır")
        }
    }

    private func stepBadge(index: Int, title: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(currentStep == index ? settings.accentColorChoice.color : (currentStep > index ? Color.green : Color.secondary.opacity(0.18)))
                    .frame(width: 18, height: 18)

                if currentStep > index {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(currentStep == index ? .white : .secondary)
                }
            }

            Text(title)
                .font(.system(size: 11, weight: currentStep == index ? .semibold : .regular))
                .foregroundColor(currentStep == index ? .primary : .secondary)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentStep)
    }

    private func stepConnector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.green.opacity(0.8) : Color.secondary.opacity(0.2))
            .frame(width: 14, height: 2)
            .cornerRadius(1)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: active)
    }

    // MARK: - 1. Adım: Hoş Geldiniz (Kompakt, Asla Kesilmez)

    private var welcomeStepView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Uygulama Simgesi Vitrini
                ZStack {
                    Circle()
                        .fill(settings.accentColorChoice.color.opacity(0.08))
                        .frame(width: 84, height: 84)

                    if let appIcon = NSApplication.shared.applicationIconImage {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                    } else {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(settings.accentColorChoice.color)
                    }
                }
                .padding(.top, 8)

                // Başlık ve Açıklama
                VStack(spacing: 4) {
                    Text("UnPack")
                        .font(.system(size: 22, weight: .bold))

                    Text("macOS için hızlı, sade ve güvenilir arşiv yöneticisi.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Öne Çıkan Özellikler Listesi
                VStack(spacing: 8) {
                    featureRow(
                        icon: "bolt.fill",
                        iconColor: .blue,
                        title: "Gelişmiş Arşivleme Motoru",
                        subtitle: "RAR, 7Z, ZIP ve TAR formatlarında anında çıkarma, içerik önizleme ve güçlü şifreleme."
                    )

                    featureRow(
                        icon: "shield.checkerboard",
                        iconColor: .teal,
                        title: "Akıllı Dağılma Koruması",
                        subtitle: "Çok dosyalı arşivleri tespit eder; masaüstünüzü dağıtmadan tek bir düzenli klasöre açar."
                    )

                    featureRow(
                        icon: "sparkles",
                        iconColor: settings.accentColorChoice.color,
                        title: "Temiz Arşivleme Filtresi",
                        subtitle: "Gizli .DS_Store artıklarını ayıklar; Windows ve Linux sistemleriyle tam uyum sağlar."
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.2)
            }

            Spacer()
        }
    }

    // MARK: - 2. Adım: Yapılandırma & Kurulum (Kompakt & Kaydırılabilir)

    private var configurationStepView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 3) {
                Text("Hızlı Kurulum & Tercihler")
                    .font(.system(size: 18, weight: .bold))

                Text("Tüm ayarlar önerilen seçeneklerle hazırlandı. Dilediğinizi özelleştirebilirsiniz.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 7) {
                    // DMG'den açıldıysa Uygulamalar'a Kurulum Kartı
                    if isRunningOutsideApplications {
                        configurationCard(
                            id: "install_app",
                            icon: "arrow.down.app.fill",
                            color: settings.accentColorChoice.color,
                            title: "Uygulamalar Klasörüne Yükle",
                            badge: "Önerilen",
                            badgeColor: settings.accentColorChoice.color,
                            description: "UnPack'i kalıcı olarak /Applications dizinine kopyalar ve Launchpad'e ekler.",
                            isOn: $stepState.isInstallToApplicationsSelected
                        )
                    }

                    // 1. Saptanmış Arşiv Uygulaması
                    configurationCard(
                        id: "default_app",
                        icon: "archivebox.fill",
                        color: .blue,
                        title: "Saptanmış Arşiv Yöneticisi Yap",
                        badge: "Önerilen",
                        badgeColor: .blue,
                        description: ".rar, .zip, .7z ve .tar dosyaları Finder'da otomatik olarak UnPack ile açılır.",
                        isOn: $stepState.isDefaultAppSelected
                    )

                    // 2. Finder Sağ Tık Menüsü
                    configurationCard(
                        id: "finder_sync",
                        icon: "macwindow.on.rectangle",
                        color: .indigo,
                        title: "Finder Sağ Tık Entegrasyonu",
                        badge: "Kısayol",
                        badgeColor: .indigo,
                        description: "Finder bağlam menüsüne 'UnPack ile Sıkıştır' ve 'Buraya Çıkart' seçeneklerini ekler.",
                        isOn: $stepState.isFinderIntegrationSelected
                    )

                    // 3. Bildirimler ve Sesler
                    configurationCard(
                        id: "notifications",
                        icon: "bell.badge.fill",
                        color: settings.accentColorChoice.color,
                        title: "İşlem Bildirimleri & Sesli Uyarılar",
                        badge: "Sistem",
                        badgeColor: settings.accentColorChoice.color,
                        description: "Büyük arşivler arka planda tamamlandığında sistem bildirimi ve ses verir.",
                        isOn: $stepState.isNotificationsSelected
                    )

                    // 4. Akıllı Çıkarma & Temizlik
                    configurationCard(
                        id: "clean_filter",
                        icon: "sparkles",
                        color: .mint,
                        title: "Akıllı Çıkarma & Çöp Dosya Temizliği",
                        badge: "Otomasyon",
                        badgeColor: .mint,
                        description: "Dağınık arşivleri korur ve harici disklere aktarırken .DS_Store artıklarını temizler.",
                        isOn: $stepState.isCleanJunkSelected
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            if isApplying {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(progressMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func configurationCard(
        id: String,
        icon: String,
        color: Color,
        title: String,
        badge: String,
        badgeColor: Color,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        Button(action: {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                isOn.wrappedValue.toggle()
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Sol İkon
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 30, height: 30)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }

                // Orta Başlık & Metin
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(badge)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(badgeColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(description)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(1.2)
                }

                Spacer()

                // Sağ Onay Kutusu (Zarif Checkbox)
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn.wrappedValue ? settings.accentColorChoice.color : Color(NSColor.controlBackgroundColor))
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(isOn.wrappedValue ? Color.clear : Color(NSColor.separatorColor), lineWidth: 1.2)
                        )

                    if isOn.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 4)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isOn.wrappedValue ? settings.accentColorChoice.color.opacity(0.8) : Color(NSColor.separatorColor),
                        lineWidth: isOn.wrappedValue ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Adım: Sistem İzinleri (Dosya, Finder, Bildirim)

    private var permissionsStepView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 3) {
                Text("Sistem ve Güvenlik İzinleri")
                    .font(.system(size: 18, weight: .bold))

                Text("UnPack'in arşivleri güvenle yönetebilmesi ve Finder ile bütünleşmesi için gerekli izinler.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Button(action: grantAllPermissions) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Tüm İzinleri Otomatik Tanımla")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.horizontal, 20)
            .padding(.top, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 9) {
                    // 1. Dosya ve Disk Erişimi
                    permissionCard(
                        icon: "folder.badge.gearshape",
                        color: .blue,
                        title: "Dosya ve Disk Erişimi",
                        badge: "Temel İzin",
                        badgeColor: .blue,
                        description: "Masaüstü, İndirilenler ve harici sürücülerdeki arşivleri açabilmek ve yeni arşivler oluşturabilmek için dosya erişimi gereklidir.",
                        actionTitle: hasDiskAccessPermission ? "Erişim Doğrulandı" : "Sistem Ayarlarını Aç",
                        isGranted: hasDiskAccessPermission,
                        action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )

                    // 2. Finder Sağ Tık Menü Uzantısı
                    permissionCard(
                        icon: "macwindow.on.rectangle",
                        color: .indigo,
                        title: "Finder Sağ Tık Menü Uzantısı",
                        badge: "Kısayol",
                        badgeColor: .indigo,
                        description: "Finder bağlam menüsünde 'UnPack ile Sıkıştır' ve 'Buraya Çıkart' seçeneklerini doğrudan kullanabilmenizi sağlar.",
                        actionTitle: isFinderExtensionActive ? "Etkinleştirildi" : "Uzantıyı Aç",
                        isGranted: isFinderExtensionActive,
                        action: {
                            FIFinderSyncController.showExtensionManagementInterface()
                            isFinderExtensionActive = true
                        }
                    )

                    // 3. Sistem Bildirimleri ve Uyarı Sesleri
                    permissionCard(
                        icon: "bell.badge.fill",
                        color: settings.accentColorChoice.color,
                        title: "İşlem Tamamlanma Bildirimleri",
                        badge: "Sistem",
                        badgeColor: settings.accentColorChoice.color,
                        description: "Büyük arşivler arka planda tamamlandığında ekranda bildirim ve sesli uyarı verir.",
                        actionTitle: hasNotificationPermission ? "İzin Verildi" : "Bildirim İzni Ver",
                        isGranted: hasNotificationPermission,
                        action: {
                            Task {
                                let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                                await MainActor.run {
                                    self.hasNotificationPermission = granted
                                }
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            .onAppear {
                checkPermissionsStatus()
            }
        }
    }

    private func permissionCard(
        icon: String,
        color: Color,
        title: String,
        badge: String,
        badgeColor: Color,
        description: String,
        actionTitle: String,
        isGranted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(badge)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(badgeColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.3)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Etkin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            } else {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private func grantAllPermissions() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            process.arguments = ["-e", "use", "-i", "com.unpack.app.FinderSync"]
            try? process.run()
            process.waitUntilExit()

            let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            let canReadDesktop = FileManager.default.isReadableFile(atPath: desktop.path)

            await MainActor.run {
                self.hasNotificationPermission = granted
                self.isFinderExtensionActive = true
                self.hasDiskAccessPermission = canReadDesktop
            }
        }
    }

    private func checkPermissionsStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { notifSettings in
            DispatchQueue.main.async {
                self.hasNotificationPermission = (notifSettings.authorizationStatus == .authorized)
            }
        }
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let canReadDesktop = FileManager.default.isReadableFile(atPath: desktop.path)
        self.hasDiskAccessPermission = canReadDesktop
    }

    // MARK: - 4. Adım: Tamamlandı (Hazır)

    private var completionStepView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Başarı Rozeti
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(.green)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                        .shadow(color: Color.green.opacity(0.35), radius: 10, y: 3)
                }
                .padding(.top, 12)

                VStack(spacing: 4) {
                    Text("Kurulum Başarıyla Tamamlandı")
                        .font(.system(size: 20, weight: .bold))

                    Text("UnPack artık sisteminizle tam uyumlu ve kullanıma hazır.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Etkinleştirilen Özellikler Özeti
                VStack(alignment: .leading, spacing: 8) {
                    if isInstallToApplicationsSelected && isRunningOutsideApplications {
                        completionBadgeRow(title: "Uygulama /Applications dizinine kalıcı olarak kuruldu")
                    }
                    if isDefaultAppSelected {
                        completionBadgeRow(title: "UnPack saptanmış arşiv yöneticisi olarak atandı")
                    }
                    if isFinderIntegrationSelected {
                        completionBadgeRow(title: "Finder sağ tık menüleri ve servisleri kaydedildi")
                    }
                    if isNotificationsSelected {
                        completionBadgeRow(title: "İşlem bildirimleri ve sesli uyarılar yetkilendirildi")
                    }
                    if isCleanJunkSelected {
                        completionBadgeRow(title: "Akıllı çıkarma ve sistem artığı filtresi etkinleştirildi")
                    }
                    completionBadgeRow(title: "Gerekli sistem ve dosya erişim izinleri tanımlandı")
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                if isRunningOutsideApplications {
                    Text("İpucu: Yükleyici penceresini (DMG) kapatabilir ve UnPack'i doğrudan Uygulamalar klasöründen başlatabilirsiniz.")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
    }

    private func completionBadgeRow(title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .foregroundColor(.green)
                .font(.system(size: 10, weight: .bold))

            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
    }

    // MARK: - Alt Aksiyon Barı

    private var bottomActionBar: some View {
        HStack {
            if currentStep == 1 {
                Button("Geri") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep = 0
                    }
                }
                .controlSize(.regular)
                .disabled(isApplying)
            } else if currentStep == 2 {
                Button("Geri") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                }
                .controlSize(.regular)
                .disabled(isApplying)
            } else if currentStep == 0 {
                Button("Daha Sonra") {
                    settings.hasCompletedOnboarding = true
                    withAnimation(.spring(response: 0.35)) {
                        isPresented = false
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            }

            Spacer()

            if currentStep == 0 {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Kuruluma Başla")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else if currentStep == 1 {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentStep = 2
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("İzinlere Geç")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else if currentStep == 2 {
                Button(action: {
                    applyConfigurationAndFinish()
                }) {
                    HStack(spacing: 6) {
                        if isApplying {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark")
                        }
                        Text("Onayla ve Kurulumu Tamamla")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isApplying)
            } else {
                Button("UnPack'i Başlat") {
                    settings.hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    UserDefaults.standard.synchronize()
                    withAnimation(.spring(response: 0.35)) {
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Kurulum & Yapılandırma Yürütücüsü

    private func applyConfigurationAndFinish() {
        stepState.isApplying = true
        stepState.progressMessage = "Uygulama ve ayarlar yapılandırılıyor..."

        Task {
            // 1. Gerekirse Uygulamalar (/Applications) dizinine kur
            if isInstallToApplicationsSelected && isRunningOutsideApplications {
                await MainActor.run { self.stepState.progressMessage = "Uygulamalar klasörüne kuruluyor..." }
                let currentAppURL = Bundle.main.bundleURL
                let applicationsURL = URL(fileURLWithPath: "/Applications/UnPack.app")
                do {
                    if FileManager.default.fileExists(atPath: applicationsURL.path) {
                        try FileManager.default.removeItem(at: applicationsURL)
                    }
                    try FileManager.default.copyItem(at: currentAppURL, to: applicationsURL)
                } catch {
                    print("Uygulama kopyalama notu: \(error.localizedDescription)")
                }
            }

            // 2. Saptanmış arşiv yöneticisi yap
            if isDefaultAppSelected {
                await MainActor.run { self.stepState.progressMessage = "Dosya ilişkilendirmeleri kaydediliyor..." }
                DefaultAppManager.shared.registerAsDefaultArchiveHandler()
            }
            UserDefaults.standard.set(true, forKey: "hasPromptedForDefaultArchiveHandler")

            // 3. Finder sağ tık servisleri
            if isFinderIntegrationSelected {
                await MainActor.run { self.stepState.progressMessage = "Finder servisleri etkinleştiriliyor..." }
                NSApp.servicesProvider = UnPackServicesProvider.shared
                NSUpdateDynamicServices()
                UnPackServicesProvider.shared.registerFinderServices()

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
                process.arguments = ["-e", "use", "-i", "com.unpack.app.FinderSync"]
                try? process.run()
                process.waitUntilExit()
            }

            // 4. Sistem bildirimleri
            if isNotificationsSelected {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                await MainActor.run {
                    self.settings.playSoundOnCompletion = true
                }
            }

            // 5. Ayarları kaydet ve tamamla
            await MainActor.run {
                self.settings.stripMacJunkFiles = self.isCleanJunkSelected
                self.settings.enableSmartExtraction = self.isCleanJunkSelected
                self.settings.hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                UserDefaults.standard.synchronize()
                self.stepState.isApplying = false

                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    self.stepState.currentStep = 3
                }
            }
        }
    }
}
