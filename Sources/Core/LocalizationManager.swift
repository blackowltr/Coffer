import Foundation
import SwiftUI

/// Türkçe ve İngilizce çoklu dil yöneticisi (Sistem Dili, Tercih veya MACRAR_LANG ortam değişkeni)
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @AppStorage("appLanguage") public var currentLanguage: String = "system" {
        didSet {
            objectWillChange.send()
        }
    }

    private init() {}

    /// Aktif dil kodu ("tr" veya "en")
    public var effectiveLanguageCode: String {
        // 1. COFFER_LANG / MACRAR_LANG ortam değişkeni önceliği
        if let envLang = (ProcessInfo.processInfo.environment["COFFER_LANG"] ?? ProcessInfo.processInfo.environment["MACRAR_LANG"])?.lowercased() {
            if envLang.hasPrefix("tr") { return "tr" }
            if envLang.hasPrefix("en") { return "en" }
        }

        // 2. Uygulama içi ayar
        if currentLanguage == "tr" { return "tr" }
        if currentLanguage == "en" { return "en" }

        // 3. Sistem dili
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "tr"
        if preferred.hasPrefix("tr") {
            return "tr"
        }
        return "en"
    }

    public var isTurkish: Bool {
        effectiveLanguageCode == "tr"
    }

    /// Yerelleştirilmiş metin getirir
    public func string(for key: String) -> String {
        let isTR = isTurkish
        if let entry = translations[key] {
            return isTR ? entry.tr : entry.en
        }
        return key
    }

    private struct Entry {
        let tr: String
        let en: String
    }

    private let translations: [String: Entry] = [
        // Menüler & Genel
        "app.name": Entry(tr: "Coffer", en: "Coffer"),
        "menu.file": Entry(tr: "Dosya", en: "File"),
        "menu.openRecent": Entry(tr: "Son Kullanılanları Aç", en: "Open Recent"),
        "menu.clearRecent": Entry(tr: "Son Kullanılanları Temizle", en: "Clear Recent"),
        "menu.newArchive": Entry(tr: "Yeni Arşiv Oluştur (Gözat)...", en: "New Archive (Browse)..."),
        "menu.openArchive": Entry(tr: "Arşiv Aç...", en: "Open Archive..."),
        "menu.view": Entry(tr: "Görünüm", en: "View"),
        "menu.expandAll": Entry(tr: "Tümünü Genişlet", en: "Expand All"),
        "menu.collapseAll": Entry(tr: "Tümünü Daralt", en: "Collapse All"),
        "menu.refresh": Entry(tr: "Yenile", en: "Refresh"),
        "menu.showInFinder": Entry(tr: "Finder'da Göster", en: "Show Archive in Finder"),
        "menu.archive": Entry(tr: "Arşiv", en: "Archive"),
        "menu.extractHere": Entry(tr: "Buraya Çıkart", en: "Extract Here"),
        "menu.extractToFolder": Entry(tr: "Klasöre Çıkart", en: "Extract to Folder"),
        "menu.extractToChosen": Entry(tr: "Belirtilen Klasöre Çıkart...", en: "Extract to Chosen Folder..."),
        "menu.extractSelected": Entry(tr: "Seçili Öğeleri Çıkart...", en: "Extract Selected Items..."),
        "menu.addFiles": Entry(tr: "Dosya Ekle...", en: "Add Files..."),
        "menu.deleteSelected": Entry(tr: "Seçili Öğeleri Sil", en: "Delete Selected Items"),
        "menu.testArchive": Entry(tr: "Arşiv Bütünlüğünü Test Et", en: "Test Archive Integrity"),
        "menu.archiveInfo": Entry(tr: "Arşiv Bilgileri", en: "Archive Info"),
        "menu.repairArchive": Entry(tr: "Hasarlı Arşivi Onar...", en: "Repair Archive..."),
        "menu.checkUpdates": Entry(tr: "Güncellemeleri Denetle...", en: "Check for Updates..."),
        "menu.fileAssociations": Entry(tr: "Dosya İlişkilendirmeleri...", en: "File Associations..."),
        "menu.installRarTool": Entry(tr: "RAR Aracını Yükle / Yapılandır...", en: "Install RAR Tool..."),
        "menu.reinstallQuickActions": Entry(tr: "Finder Hızlı Eylemlerini Yeniden Yükle", en: "(Re)install Finder Quick Actions"),
        "menu.settings": Entry(tr: "Ayarlar...", en: "Settings..."),

        // Tablo Sütunları
        "col.name": Entry(tr: "Dosya Adı", en: "Name"),
        "col.size": Entry(tr: "Boyut", en: "Size"),
        "col.packedSize": Entry(tr: "Paketlenmiş", en: "Packed Size"),
        "col.ratio": Entry(tr: "Oran", en: "Ratio"),
        "col.date": Entry(tr: "Değiştirilme Tarihi", en: "Modification Date"),
        "col.crc": Entry(tr: "CRC32", en: "CRC"),
        "col.type": Entry(tr: "Tür", en: "Type"),

        // Durum Çubuğu & Rozetler
        "status.ready": Entry(tr: "Hazır", en: "Ready"),
        "status.solid": Entry(tr: "Katı Arşiv", en: "Solid"),
        "status.encryptedHeaders": Entry(tr: "Şifreli Başlıklar", en: "Encrypted Headers"),
        "status.volumes": Entry(tr: "Çok Parçalı", en: "Multi-volume"),
        "status.items": Entry(tr: "öğe", en: "items"),
        "status.total": Entry(tr: "Toplam", en: "Total"),
        "status.selected": Entry(tr: "Seçili", en: "Selected"),

        // Arama & Gözatma
        "search.placeholder": Entry(tr: "Tüm arşivde yol veya dosya adına göre ara...", en: "Search entire archive by path or name..."),
        "search.noResults": Entry(tr: "Sonuç bulunamadı", en: "No matching items"),

        // Çıkarma Çakışma Penceresi
        "conflict.title": Entry(tr: "Dosya Zaten Mevcut", en: "File Already Exists"),
        "conflict.message": Entry(tr: "Hedef klasörde aynı isimde bir dosya zaten var. Ne yapmak istersiniz?", en: "The destination already contains an item with the same name. What would you like to do?"),
        "conflict.overwrite": Entry(tr: "Üzerine Yaz", en: "Overwrite"),
        "conflict.autoRename": Entry(tr: "Otomatik Yeniden Adlandır", en: "Auto-Rename"),
        "conflict.skip": Entry(tr: "Atla", en: "Skip"),
        "conflict.cancel": Entry(tr: "İptal", en: "Cancel"),
        "conflict.applyAll": Entry(tr: "Tüm çakışmalara uygula", en: "Apply to all remaining conflicts"),

        // İlerleme Penceresi
        "progress.elapsed": Entry(tr: "Geçen Süre", en: "Elapsed Time"),
        "progress.remaining": Entry(tr: "Kalan Süre", en: "Estimated Remaining"),
        "progress.speed": Entry(tr: "İşlem Hızı", en: "Speed"),
        "progress.processed": Entry(tr: "İşlenen", en: "Processed"),
        "progress.log": Entry(tr: "İşlenen Dosyaların Günlüğü", en: "Processed Files Log"),
        "progress.cancel": Entry(tr: "Durdur ve İptal Et", en: "Cancel Operation")
    ]
}

public extension String {
    var loc: String {
        LocalizationManager.shared.string(for: self)
    }
}
