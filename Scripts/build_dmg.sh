#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="Coffer"
VERSION="1.2.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
DESKTOP_DIR="${HOME}/Desktop/Coffer"
DESKTOP_KURULUM_DIR="${HOME}/Desktop/Coffer-Kurulum"
STAGING_DIR="${BUILD_DIR}/dmg_staging"

echo "==> Packaging professional ${DMG_NAME}..."

# Ensure App bundle exists and is fresh
if [ ! -d "${BUILD_DIR}/${APP_NAME}.app" ]; then
    "${PROJECT_DIR}/Scripts/bundle_app.sh"
fi

# Clean previous staging and dmg
rm -rf "${STAGING_DIR}"
rm -f "${DMG_PATH}"

mkdir -p "${STAGING_DIR}"

echo "==> Staging application and Applications symlink..."
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Add Kurulum Rehberi into DMG
cat << 'EOF' > "${BUILD_DIR}/Kurulum_Rehberi.txt"
=====================================================
          Coffer 1.0 - Hızlı Kurulum Rehberi
=====================================================

Coffer'ı Mac'inize kurmak için 2 kolay yöntem vardır:

YÖNTEM 1 (Klasik Mac Sürükle-Bırak):
1. Bu penceredeki "Coffer" uygulamasını "Applications" (Uygulamalar) klasörünün üzerine sürükleyip bırakın.
2. Uygulamalar'dan Coffer'ı açın. Karşınıza gelen Kurulum Sihirbazı'nda "Kurulumu Tamamla" butonuna basın.

YÖNTEM 2 (Otomatik Tek Tıkla Kurulum):
1. "Hızlı_Kurulum.command" dosyasına çift tıklayın.
2. Coffer otomatik olarak Uygulamalar klasörüne taşınacak, güvenlik izinleri verilecek ve başlatılacaktır.

-----------------------------------------------------
ÖNEMLİ (Apple Güvenlik Uyarısı / Gatekeeper):
İnternetten veya harici kaynaktan indirilen uygulamalarda
macOS ilk açılışta "Geliştirici doğrulanamadı" uyarısı gösterebilir.
Bunu aşmak için:
-> Uygulamaya SAĞ TIKLAYIP (veya Control tuşuna basıp) "Aç" deyin,
   çıkan pencerede "Aç" butonuna basın.
(Bu işlem yalnızca İLK AÇILIŞTA 1 KEZ yapılır, sonrasında normal açılır.)
-----------------------------------------------------

Tebrikler! RAR, ZIP, 7Z ve TAR dosyalarınız artık Coffer ile güvende.
EOF
cp "${BUILD_DIR}/Kurulum_Rehberi.txt" "${STAGING_DIR}/Kurulum_Rehberi.txt"

# Add Hızlı Kurulum.command into DMG and Desktop
cat << 'EOF' > "${BUILD_DIR}/Hızlı_Kurulum.command"
#!/usr/bin/env bash
set -e
clear

echo "====================================================="
echo "           Coffer 1.0 - Otomatik Kurulum             "
echo "====================================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH=""

if [ -d "${SCRIPT_DIR}/Coffer.app" ]; then
    APP_PATH="${SCRIPT_DIR}/Coffer.app"
elif [ -d "/Volumes/Coffer/Coffer.app" ]; then
    APP_PATH="/Volumes/Coffer/Coffer.app"
elif [ -d "${HOME}/Desktop/Coffer-Kurulum/Coffer.app" ]; then
    APP_PATH="${HOME}/Desktop/Coffer-Kurulum/Coffer.app"
elif [ -d "${HOME}/Desktop/Coffer/Coffer.app" ]; then
    APP_PATH="${HOME}/Desktop/Coffer/Coffer.app"
fi

if [ -z "${APP_PATH}" ] || [ ! -d "${APP_PATH}" ]; then
    echo "❌ HATA: Coffer.app paketi bulunamadı!"
    echo "Lütfen bu dosyayı Coffer.app dosyasının yanında çalıştırın."
    echo ""
    read -p "Çıkmak için Enter'a basın..."
    exit 1
fi

echo "==> 1/4: Coffer.app Uygulamalar (/Applications) klasörüne kopyalanıyor..."
pkill -x "Coffer" 2>/dev/null || true
rm -rf "/Applications/Coffer.app"
cp -R "${APP_PATH}" "/Applications/Coffer.app"

echo "==> 2/4: macOS Gatekeeper güvenlik karantinası kaldırılıyor..."
xattr -cr "/Applications/Coffer.app" 2>/dev/null || true

echo "==> 3/4: Finder eklentisi (CofferFinderSync) kaydediliyor..."
pluginkit -a "/Applications/Coffer.app/Contents/PlugIns/CofferFinderSync.appex" 2>/dev/null || true
pluginkit -e use -i com.coffer.app.FinderSync 2>/dev/null || true

echo "==> 4/4: Coffer başlatılıyor..."
open "/Applications/Coffer.app"

echo ""
echo "====================================================="
echo "🎉 Tebrikler! Coffer başarıyla kuruldu ve başlatıldı."
echo "   RAR, ZIP, 7Z, TAR dosyalarınız artık Coffer ile açılacak."
echo "====================================================="
echo ""
sleep 2
EOF
chmod +x "${BUILD_DIR}/Hızlı_Kurulum.command"
cp "${BUILD_DIR}/Hızlı_Kurulum.command" "${STAGING_DIR}/Hızlı_Kurulum.command"

# Set custom volume icon if AppIcon.icns exists
if [ -f "${BUILD_DIR}/AppIcon.icns" ]; then
    cp "${BUILD_DIR}/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
    if command -v SetFile &> /dev/null; then
        SetFile -c icnC "${STAGING_DIR}/.VolumeIcon.icns" || true
        SetFile -a C "${STAGING_DIR}" || true
    fi
fi

echo "==> Creating compressed disk image with hdiutil..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_PATH}"

# Cleanup staging
rm -rf "${STAGING_DIR}"

echo "==> Copying to Desktop distribution directory: ${DESKTOP_DIR}..."
mkdir -p "${DESKTOP_DIR}"
cp -f "${DMG_PATH}" "${DESKTOP_DIR}/${DMG_NAME}"
cp -f "${DMG_PATH}" "${DESKTOP_DIR}/${APP_NAME}.dmg"
cp -f "${BUILD_DIR}/Kurulum_Rehberi.txt" "${DESKTOP_DIR}/Kurulum_Rehberi.txt" 2>/dev/null || true
cp -f "${BUILD_DIR}/Hızlı_Kurulum.command" "${DESKTOP_DIR}/Hızlı_Kurulum.command" 2>/dev/null || true
chmod +x "${DESKTOP_DIR}/Hızlı_Kurulum.command"

# Also place clean Coffer.app and ZIP in Desktop directory
echo "==> Mirroring Coffer.app and ZIP to ${DESKTOP_DIR}..."
rm -rf "${DESKTOP_DIR}/Coffer.app"
cp -R "${BUILD_DIR}/Coffer.app" "${DESKTOP_DIR}/Coffer.app"
xattr -cr "${DESKTOP_DIR}/Coffer.app" 2>/dev/null || true
(cd "${BUILD_DIR}" && zip -rq "${DESKTOP_DIR}/Coffer-${VERSION}.zip" "Coffer.app")

# Add detailed Readme for End Users
cat << 'EOF' > "${DESKTOP_DIR}/BENİ_OKU_VE_KURULUM.md"
# Coffer 1.1 - macOS Arşiv Yöneticisi

Coffer, macOS ekosistemi için sıfırdan geliştirilmiş, Liquid Glass tasarım diliyle harmanlanmış yeni nesil arşivleme ve dosya yönetim aracıdır.

## 🚀 Hızlı Kurulum Seçenekleri

Son kullanıcılar için 2 kolay yöntem sunulmuştur:

### 1. Yöntem: Otomatik Tek Tıkla Kurulum (Önerilen)
- Klasördeki **`Hızlı_Kurulum.command`** dosyasına çift tıklayın.
- Coffer otomatik olarak `/Applications` (Uygulamalar) klasörünüze kopyalanır, macOS Gatekeeper izinleri verilir ve uygulama başlatılır.

### 2. Yöntem: DMG Kalıbı ile Klasik Kurulum
- **`Coffer-1.1.0.dmg`** veya **`Coffer.dmg`** dosyasına çift tıklayarak disk kalıbını açın.
- Coffer simgesini **Applications** klasörüne sürükleyip bırakın.
- Uygulamalar klasöründen Coffer'ı başlatın.

> **Apple Güvenlik Uyarısı (Gatekeeper):**
> macOS ilk açılışta *"Geliştirici doğrulanamadı"* uyarısı verirse:
> Uygulamaya **Sağ Tıklayın (veya Control tuşuyla tıklayın) > "Aç"** deyin ve onaylayın.

---

## 💎 Temel Özellikler
- **Desteklenen Formatlar:** RAR, RAR5, ZIP, 7Z, TAR, TAR.GZ, TAR.XZ, TAR.BZ2, BZ2, GZ, XZ
- **Çift Mod:** WinRAR tarzı detaylı **Gezgin Modu** ve sürükle-bırak **Hızlı Mod**.
- **Tam Güvenlik:** AES-256 Şifreleme, Dosya Adı Gizleme (-hp/-mhe), Bütünlük Denetimi (CRC32/BLAKE2sp).
- **Akıllı macOS Temizleyici:** Arşivlerden `.DS_Store`, `__MACOSX` ve `._*` kalıntılarını otomatik filtreleme.
- **Finder Entegrasyonu:** Sağ tık içerik menüsünden doğrudan çıkarma ve sıkıştırma.
- **Dahili Güncelleyici:** Uygulama içerisinden GitHub güncellemelerini tek tıkla indirip kurma.
EOF

# Also sync installed app to /Applications
echo "==> Updating /Applications/Coffer.app..."
rm -rf "/Applications/Coffer.app"
cp -R "${BUILD_DIR}/Coffer.app" "/Applications/Coffer.app"
xattr -cr "/Applications/Coffer.app" 2>/dev/null || true

# Compute SHA256 Checksums
echo "==> Computing SHA-256 Checksums..."
DMG_SHA256=$(shasum -a 256 "${DESKTOP_DIR}/${DMG_NAME}" | cut -d ' ' -f 1)
ZIP_SHA256=$(shasum -a 256 "${DESKTOP_DIR}/Coffer-${VERSION}.zip" | cut -d ' ' -f 1)

cat << EOF > "${DESKTOP_DIR}/SHA256_KONTROL.txt"
=====================================================
          Coffer ${VERSION} - SHA-256 Doğrulama Kodları
=====================================================

Coffer-${VERSION}.dmg:
${DMG_SHA256}

Coffer-${VERSION}.zip:
${ZIP_SHA256}

Doğrulamak için Terminal'de çalıştırın:
shasum -a 256 Coffer-${VERSION}.dmg
EOF

# Sync to DESKTOP_KURULUM_DIR
if [ -d "${DESKTOP_KURULUM_DIR}" ]; then
    echo "==> Syncing to ${DESKTOP_KURULUM_DIR}..."
    cp -f "${DESKTOP_DIR}/${DMG_NAME}" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/${APP_NAME}.dmg" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/Coffer-${VERSION}.zip" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/Hızlı_Kurulum.command" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/Kurulum_Rehberi.txt" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/BENİ_OKU_VE_KURULUM.md" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/SHA256_KONTROL.txt" "${DESKTOP_KURULUM_DIR}/"
    rm -rf "${DESKTOP_KURULUM_DIR}/Coffer.app"
    cp -R "${BUILD_DIR}/Coffer.app" "${DESKTOP_KURULUM_DIR}/Coffer.app"
    xattr -cr "${DESKTOP_KURULUM_DIR}" 2>/dev/null || true
fi

# Clean temporary files & strip quarantine from desktop distribution
rm -f "${DESKTOP_DIR}/.DS_Store" 2>/dev/null || true
xattr -cr "${DESKTOP_DIR}" 2>/dev/null || true

echo "==> DMG created successfully at: ${DMG_PATH}"
echo "==> Desktop distribution updated at: ${DESKTOP_DIR}"
echo "==> DMG File Size: $(du -sh "${DMG_PATH}" | cut -f1)"
echo "==> SHA-256 Checksum: ${DMG_SHA256}"
