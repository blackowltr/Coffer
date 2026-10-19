# Coffer

**macOS için modern, akıllı ve zarif arşiv yöneticisi.**

[![Web Sitesi](https://img.shields.io/badge/Web_Sitesi-blackowltr.github.io%2FCoffer-3b82f6?style=for-the-badge&logo=safari&logoColor=white)](https://blackowltr.github.io/Coffer/)
[![Son Sürüm](https://img.shields.io/github/v/release/blackowltr/Coffer?style=for-the-badge&color=8b5cf6&label=S%C3%BCr%C3%BCm)](https://github.com/blackowltr/Coffer/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B%20(Sonoma%20%26%20Sequoia)-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/blackowltr/Coffer)
[![Lisans](https://img.shields.io/badge/Lisans-MIT-green?style=for-the-badge)](LICENSE)

> 🌐 **Canlı Tanıtım Sitesi:** Coffer'ın arayüz vitrini, özellikler tablosu ve detaylı bilgilerine web sitemizden göz atabilirsiniz: **[blackowltr.github.io/Coffer](https://blackowltr.github.io/Coffer/)**

Coffer; hafif, hızlı ve macOS tasarım standartlarına sadık kalınarak saf Swift ve SwiftUI ile geliştirilmiş bir arşiv yönetim uygulamasıdır.

Apple Silicon (M1–M4) ve Intel işlemcileri evrensel (Universal Binary) olarak yerel hızda destekler; arka planda sistem kaynaklarını yormadan güvenli ve akıcı bir arşivleme deneyimi sunar.

---

## ✨ Temel Özellikler

### 1. 🗂️ Çift Çalışma Modu
* **Gezgin Modu:** Arşiv içeriğini diske çıkarmadan doğrudan görüntüleyin. Ağaç yapısındaki kenar çubuğu ve dosya listesi üzerinden klasörler arasında gezinin, aradığınız dosyaları hızla filtreleyin veya Quick Look ile anında önizleyin.
* **Hızlı Bırakma Alanı:** Dosyalarınızı pencereye sürükleyip bırakarak saniyeler içinde yeni bir arşiv oluşturun veya mevcut arşivleri tek adımda açın.

### 2. 🛡️ Akıllı Çıkarma (Smart Extraction)
* Çok sayıda dağınık dosyadan oluşan arşivlerde masaüstünüzün düzenini korumak için içeriği otomatik olarak arşiv adını taşıyan bir klasör içine açar.
* Zaten tek bir ana klasör barındıran arşivleri doğrudan hedef dizine çıkararak gereksiz iç içe klasör oluşumunu engeller.

### 3. 🖱️ Finder Entegrasyonu
* macOS Finder üzerinden dosya ve arşivlere sağ tıklayarak doğrudan işlem yapın:
  * **Buraya Çıkart**
  * **Klasöre Çıkart**
  * **ZIP Olarak Sıkıştır**
  * **Coffer ile Sıkıştır...** (Gelişmiş seçenekler)

### 4. 🔒 Güvenlik ve Bütünlük
* **AES-256 Şifreleme:** Arşivlerinizi güçlü parolalar ve isteğe bağlı başlık (dosya adı) şifrelemesiyle koruyun.
* **Güvenlik Taraması:** Arşiv açılmadan önce Zip Slip güvenlik açıklarına ve gizli yürütülebilir dosyalara karşı otomatik ön kontrol sağlar.
* **Bütünlük Testi:** Arşiv dosyalarının sağlamlığını ve sağlama toplamlarını (CRC32) tek tıkla test edin.

### 5. 🔄 Arşiv Dönüştürme & Karşılaştırma
* **Format Dönüştürücü:** Arşivleri diske çıkarmaya gerek kalmadan doğrudan farklı bir formata (ör. RAR'dan 7Z veya ZIP'e) dönüştürün.
* **Arşiv Farkı (Diff):** İki arşiv arasındaki eklenen, silinen ve güncellenen dosyaları görsel rozetlerle karşılaştırın.

### 6. 🎨 Kişiselleştirilebilir Modern Tasarım
* macOS Sequoia ve Sonoma arayüz estetiğiyle tam uyum.
* Seçilen vurgu rengine duyarlı modern ve minimalist bileşenler.
* Koyu ve açık tema desteği.

---

## 📦 Desteklenen Formatlar

| Format | Görüntüleme & Açma | Oluşturma & Sıkıştırma |
| :--- | :---: | :---: |
| **ZIP** | ✅ | ✅ |
| **TAR / GZ / BZ2 / XZ** | ✅ | ✅ |
| **7-Zip (.7z)** | ✅ | ✅ |
| **RAR (.rar)** | ✅ | ✅ *(RAR for macOS ile)* |
| **Çok Parçalı Arşivler** (`.part1.rar`, `.001` vb.) | ✅ | ✅ |

---

## 💻 Sistem Gereksinimleri

* macOS 14.0 (Sonoma) veya üzeri
* Apple Silicon (M1/M2/M3/M4) veya Intel x86_64 işlemci

---

## 🚀 Kurulum

1. En güncel `.dmg` kurulum kalıbını **[Web Sitemizden](https://blackowltr.github.io/Coffer/)** veya doğrudan **[GitHub Releases](https://github.com/blackowltr/Coffer/releases)** sayfasından indirin (`Coffer-1.0.0.dmg`).
2. İndirilen DMG dosyasını açıp `Coffer.app` uygulamasını `Uygulamalar` (Applications) klasörünüze sürükleyin.
3. Coffer'ı ilk kez çalıştırdığınızda karşılama sihirbazı gerekli sistem izinlerini otomatik olarak yapılandırır ve sonrasında arka planda sessizce çalışır.

---

## 📄 Lisans

Bu proje MIT Lisansı altında sunulmaktadır.
