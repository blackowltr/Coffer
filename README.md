# 🗜️ Coffer — macOS İçin Modern & Güçlü Arşiv Yöneticisi

> **Saf Swift & SwiftUI ile geliştirilmiş, ultra hafif (~1.6 MB), Universal Binary (Apple Silicon M1-M4 & Intel x86_64), %100 Türkçe & İngilizce profesyonel arşiv yöneticisi.**

---

## 🇹🇷 Türkçe Tanıtım

**Coffer**, macOS platformunda Windows'un efsanevi **WinRAR** deneyimini, Keka'nın hızını ve modern macOS Sonoma/Sequoia arayüz dilini birleştiren gelişmiş bir arşiv yönetim çözümüdür.

Rosetta 2 emülasyonuna veya hantal web motorlarına gerek kalmadan, hem **Apple Silicon ARM64** hem de **Intel x86_64** mimarilerine evrensel (Universal) olarak derlenmiştir. Arka planda yalnızca **~25-35 MB RAM** tüketir ve işlemci çekirdeklerini asenkron `Actor` mimarisiyle tam kapasite kullanır.

---

### 🌟 Öne Çıkan Özellikler

#### 1. 🗂️ Çift Modlu Kullanım Deneyimi
* **Gezgin Modu (WinRAR Tarzı):**
  * Arşivi diske çıkarmadan içerisindeki klasör hiyerarşisinde gezinme.
  * **Akıllı Açılır/Kapanır (Accordion Tree) Kenar Çubuğu:** Klasörler varsayılan olarak derli toplu kapalı durur; tıklandığında akıcı yay animasyonuyla alta doğru genişler. Kafa karışıklığı ve upuzun liste karmaşası önlenir. Tek tıkla tümünü genişletme/daraltma butonu içerir.
  * Zengin tablo görünümü: Dosya Adı, Orijinal Boyut, Sıkıştırılmış Boyut, Sıkıştırma Oranı (%), Değiştirilme Tarihi, Tür ve CRC32 sağlama toplamı.
  * **İkonik Araç Çubuğu:** Ekle (Arşivle), Çıkart, Test Et, Görüntüle (Quick Look), Sil, Dönüştür, Fark (Diff), Bilgi, Kilitle ve Onar.
  * **Ekmek Kırıntısı (Breadcrumb) & Hızlı Arama:** Arşiv içinde anında yol takibi ve dosya filtreleme.
* **Hızlı Bırakma Modu (Keka Tarzı):**
  * Minimalist, animasyonlu sürükle-bırak bırakma alanı (Drop Zone).
  * Arşiv dosyası bırakıldığında otomatik ayıklar, normal dosya bırakıldığında sıkıştırma sihirbazını başlatır.

#### 2. 💻 MacBook Air M2 & Pro Donanım Kamera Çentiği (Notch) Bırakma Alanı
* Ekranın en üstünde yer alan fiziksel MacBook kamera çentiğine tam oturan, sistem geneli kayan (Floating Overlay) bırakma motoru.
* Finder'da veya herhangi bir uygulamada bir dosyayı ekranın en üstündeki kamera çentiğine doğru sürüklediğiniz anda:
  * Kamera çentiği aşağıya doğru `0.35s` yay animasyonuyla genişler ve parıldayan bir bırakma hedefi açar.
  * Dosyayı çentiğe bıraktığınızda ışık parlaması ve ses efektiyle birlikte anında sıkıştırma (arşiv ise açma) işlemi başlatılır.
  * Çentikten fare çekildiğinde otomatik olarak tekrar kameranın arkasına gizlenir.
  * Ayarlar (`Cmd+,`) üzerinden tek tıkla açılıp kapatılabilir.

#### 3. 📂 Gelişmiş Gözat (Browse) Desteği
* Sürükle-bırak yapmaya gerek kalmadan, hem ana araç çubuğundaki **"Sıkıştır"** butonuyla hem de karşılama ekranındaki **"Dosya Seç (Gözat)..."** butonuyla dilediğiniz dosya veya klasörleri seçip doğrudan sıkıştırma sihirbazını başlatabilirsiniz.

#### 4. 🖱️ Finder Sağ Tık Entegrasyonu (WinRAR Tarzı Context Menu)
* macOS Finder'da herhangi bir dosyaya veya arşive sağ tıkladığınızda (veya Hızlı Eylemler / Servisler menüsünde) WinRAR mantığında yer alan seçenekler:
  * 🗜️ **Coffer: Buraya Çıkart** — Arşivi doğrudan bulunduğu klasöre ayıklar.
  * 📁 **Coffer: Klasöre Çıkart (Adıyla)** — Arşiv adında yeni bir klasör oluşturup tüm içeriği içine çıkartır.
  * 🗜️ **Coffer: ZIP Olarak Sıkıştır** — Seçilen dosya veya klasörleri tek tıkla arka planda anında `.zip` yapar.
  * ⚙️ **Coffer ile Sıkıştır...** — Seçilen dosyalarla birlikte Coffer sıkıştırma sihirbazını açarak format, şifre ve seviye seçimi sunar.

#### 5. 🔮 Liquid Glass Menü Çubuğu (Menu Bar) Widget'ı
* Üst menü çubuğunda çalışan akrilik Liquid Glass mini pencere.
* Dosyaları doğrudan menü çubuğu simgesine sürükleyip bırakarak anında açma veya sıkıştırma.
* Tek tıkla ana pencereye geçiş ve hızlı arşiv seçimi.

#### 6. ⚖️ Arşiv Karşılaştırma / Fark (Diff) Aracı
* İki arşiv arasındaki (ör. `yedek_v1.zip` ile `yedek_v2.zip`) dosya değişikliklerini analiz eder.
* **Görsel Rozetler:** 🟢 Eklenenler (+), 🔴 Silinenler (-), 🟡 Değişenler (Δ - Boyut/CRC farkı), ⚪ Değişmeyenler (=).
* Filtreli sekme sistemi ve anlık dosya karşılaştırma tablosu.

#### 4. 🛡️ Akıllı Çıkarma (Anti-Folder-Bomb Koruması)
* Arşivde tek bir ana klasör varsa doğrudan hedef konuma çıkarır.
* Arşivde yüzlerce dağınık dosya varsa (klasör bombası riski), Masaüstü'nü çöplüğe çevirmemek için otomatik olarak arşiv adıyla yeni bir klasör açıp içine çıkarır.
* Ayarlardan kullanıcı isteğine göre açılıp kapatılabilir.

#### 5. ⚡ Çıkarma Sonrası Otomasyon Eylemleri
* Çıkarma tamamlandığında:
  * Orijinal arşivi otomatik olarak **Çöp Sepeti'ne taşıma** (isteğe bağlı).
  * Çıkan klasörü doğrudan **Finder'da seçili açma**.
  * Sesli tamamlama uyarısı verme.

#### 6. 🔄 Arşiv Dönüştürücü (Converter)
* Arşivi diske manuel olarak çıkarmadan tek tıkla farklı bir formata dönüştürme (ör. `.rar` dosyasını doğrudan `.7z` veya `.tar.gz` formatına çevirme).

#### 7. 📊 Canlı Boyut & Süre Simülatörü
* Sıkıştırma penceresinde, seçilen dosya türlerinin (metin, kod, video, fotoğraf, ikili) sıkıştırılabilirlik oranını analiz eder.
* Dosyaları sıkıştırmadan önce tahmini arşiv boyutunu (% tasarruf kazancı) ve Apple Silicon P-Core hızında tahmini işlem süresini önceden gösterir.

#### 8. ⚡ Lüks Sıkıştırma Reaktörü & Shimmer HUD Penceresi
* **Merkezi Basınç Reaktörü:** Çift yönlü dönen kesikli halkalar, içe doğru sıkışan basınç dalgaları ve neon parlaklığında durum çekirdeği.
* **Akışkan Işık Dalgası (Shimmer Bar):** Seçilen tema rengiyle %100 uyumlu, üzerinde sürekli süzülen parlak ışık süpürme efekti ve uç nokta lazer göstergesi.
* **Canlı Telemetri Kartı:** Gerçek zamanlı işlem hızı (MB/s), kalan tahmini süre ve işlenen bayt / toplam bayt göstergesi.
* **Frosted Glass Cam Efekti:** `.ultraThinMaterial` zemin, ortama yayılan renkli neon ışıma ve zarif kenar vuruşu.

#### 9. 🎨 12 Farklı Buton ve Vurgu Rengi Paleti
* Ayarlar penceresinden tek tıkla uygulamanın tüm buton, anahtar (toggle), ilerleme çubuğu ve Dinamik Ada efekt renklerini değiştirebilme:
  * 🔵 **Klasik Mavi**, 🟣 **Asil Mor**, 🌸 **Canlı Pembe**, 🔴 **Ateş Kırmızısı**
  * 🟠 **Sıcak Turuncu**, 🟡 **Altın Sarısı**, 🟢 **Zümrüt Yeşili**, 🌿 **Ferah Nane**
  * 🌊 **Okyanus Turkuazı**, 🌌 **Gece İndigosu**, 🪸 **Gül Kurusu Mercan**, 🔘 **Grafit Grisi**

#### 10. ⚙️ Kapsamlı Ayarlar Penceresi (`Cmd+,`)
* Animasyonları ve efektleri açma/kapama seçeneği.
* Açık Tema, Koyu Tema ve Sistem Teması desteği.
* Buton rengi ve vurgu paleti seçimi.
* Menü Çubuğu Widget'ı ve Dinamik Ada bırakma alanı açma/kapama.
* Varsayılan sıkıştırma formatı, çıkarma konumu ve bildirim sesleri yönetimi.

---

## 🛠️ Derleme ve Kurulum

### Gereksinimler
* macOS 14.0+ (Sonoma veya Sequoia)
* Apple Silicon (M1, M2, M3, M4) işlemci
* Swift 5.9+ / Swift 6

### Hızlı Derleme ve Çalıştırma
```bash
# 1. Kaynak kodları evrensel (Universal Apple Silicon & Intel) olarak derleyin:
./Scripts/build.sh

# 2. İmzalı Coffer.app paketini oluşturun ve LaunchServices'e kaydedin:
./Scripts/bundle_app.sh

# 3. Coffer uygulamasını başlatın:
open build/Coffer.app
```

---

## 📄 Lisans
MIT License © 2026 Coffer Contributors. (blackowltr)
