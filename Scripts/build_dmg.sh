#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="UnPack"
VERSION="1.7.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
DESKTOP_DIR="${HOME}/Desktop/UnPack"
DESKTOP_KURULUM_DIR="${HOME}/Desktop/UnPack-Kurulum"
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
          UnPack 1.7 - Hızlı Kurulum Rehberi
=====================================================

UnPack'i Mac'inize kurmak için 2 kolay yöntem vardır:

YÖNTEM 1 (Klasik Mac Sürükle-Bırak):
1. Bu penceredeki "UnPack" uygulamasını "Applications" (Uygulamalar) klasörünün üzerine sürükleyip bırakın.
2. Uygulamalar'dan UnPack'i açın. Karşınıza gelen Kurulum Sihirbazı'nda "Kurulumu Tamamla" butonuna basın.

YÖNTEM 2 (Otomatik Tek Tıkla Kurulum):
1. "Hızlı_Kurulum.command" dosyasına çift tıklayın.
2. UnPack otomatik olarak Uygulamalar klasörüne taşınacak, güvenlik izinleri verilecek ve başlatılacaktır.

-----------------------------------------------------
ÖNEMLİ (Apple Güvenlik Uyarısı / Gatekeeper):
İnternetten veya harici kaynaktan indirilen uygulamalarda
macOS ilk açılışta "Geliştirici doğrulanamadı" uyarısı gösterebilir.
Bunu aşmak için:
-> Uygulamaya SAĞ TIKLAYIP (veya Control tuşuna basıp) "Aç" deyin,
   çıkan pencerede "Aç" butonuna basın.
(Bu işlem yalnızca İLK AÇILIŞTA 1 KEZ yapılır, sonrasında normal açılır.)
-----------------------------------------------------

Tebrikler! RAR, ZIP, 7Z ve TAR dosyalarınız artık UnPack ile güvende.
EOF
cp "${BUILD_DIR}/Kurulum_Rehberi.txt" "${STAGING_DIR}/Kurulum_Rehberi.txt"

# Add Hızlı Kurulum.command into DMG and Desktop
cat << 'EOF' > "${BUILD_DIR}/Hızlı_Kurulum.command"
#!/usr/bin/env bash
set -e
clear

echo "====================================================="
echo "           UnPack 1.7 - Otomatik Kurulum             "
echo "====================================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH=""

if [ -d "${SCRIPT_DIR}/UnPack.app" ]; then
    APP_PATH="${SCRIPT_DIR}/UnPack.app"
elif [ -d "/Volumes/UnPack/UnPack.app" ]; then
    APP_PATH="/Volumes/UnPack/UnPack.app"
elif [ -d "${HOME}/Desktop/UnPack-Kurulum/UnPack.app" ]; then
    APP_PATH="${HOME}/Desktop/UnPack-Kurulum/UnPack.app"
elif [ -d "${HOME}/Desktop/UnPack/UnPack.app" ]; then
    APP_PATH="${HOME}/Desktop/UnPack/UnPack.app"
fi

if [ -z "${APP_PATH}" ] || [ ! -d "${APP_PATH}" ]; then
    echo "❌ HATA: UnPack.app paketi bulunamadı!"
    echo "Lütfen bu dosyayı UnPack.app dosyasının yanında çalıştırın."
    echo ""
    read -p "Çıkmak için Enter'a basın..."
    exit 1
fi

echo "==> 1/4: UnPack.app Uygulamalar (/Applications) klasörüne kopyalanıyor..."
pkill -x "UnPack" 2>/dev/null || true
rm -rf "/Applications/UnPack.app"
cp -R "${APP_PATH}" "/Applications/UnPack.app"

echo "==> 2/4: macOS Gatekeeper güvenlik karantinası kaldırılıyor..."
xattr -cr "/Applications/UnPack.app" 2>/dev/null || true

echo "==> 3/4: Finder eklentisi (UnPackFinderSync) kaydediliyor..."
pluginkit -a "/Applications/UnPack.app/Contents/PlugIns/UnPackFinderSync.appex" 2>/dev/null || true
pluginkit -e use -i com.unpack.app.FinderSync 2>/dev/null || true

echo "==> 4/4: UnPack başlatılıyor..."
open "/Applications/UnPack.app"

echo ""
echo "====================================================="
echo "🎉 Tebrikler! UnPack başarıyla kuruldu ve başlatıldı."
echo "   RAR, ZIP, 7Z, TAR dosyalarınız artık UnPack ile açılacak."
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

# Also place clean UnPack.app and ZIP in Desktop directory
echo "==> Mirroring UnPack.app and ZIP to ${DESKTOP_DIR}..."
rm -rf "${DESKTOP_DIR}/UnPack.app"
cp -R "${BUILD_DIR}/UnPack.app" "${DESKTOP_DIR}/UnPack.app"
xattr -cr "${DESKTOP_DIR}/UnPack.app" 2>/dev/null || true
(cd "${BUILD_DIR}" && zip -rq "${DESKTOP_DIR}/UnPack-${VERSION}.zip" "UnPack.app")

# Add detailed Readme for End Users
cat << 'EOF' > "${DESKTOP_DIR}/BENİ_OKU_VE_KURULUM.md"
# UnPack 1.7 - macOS Arşiv Yöneticisi

UnPack, macOS ekosistemi için sıfırdan geliştirilmiş, Liquid Glass tasarım diliyle harmanlanmış yeni nesil arşivleme ve dosya yönetim aracıdır.

## 🚀 Hızlı Kurulum Seçenekleri

Son kullanıcılar için 2 kolay yöntem sunulmuştur:

### 1. Yöntem: Otomatik Tek Tıkla Kurulum (Önerilen)
- Klasördeki **`Hızlı_Kurulum.command`** dosyasına çift tıklayın.
- UnPack otomatik olarak `/Applications` (Uygulamalar) klasörünüze kopyalanır, macOS Gatekeeper izinleri verilir ve uygulama başlatılır.

### 2. Yöntem: DMG Kalıbı ile Klasik Kurulum
- **`UnPack-1.7.0.dmg`** veya **`UnPack.dmg`** dosyasına çift tıklayarak disk kalıbını açın.
- UnPack simgesini **Applications** klasörüne sürükleyip bırakın.
- Uygulamalar klasöründen UnPack'i başlatın.

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
echo "==> Updating /Applications/UnPack.app..."
rm -rf "/Applications/UnPack.app"
cp -R "${BUILD_DIR}/UnPack.app" "/Applications/UnPack.app"
xattr -cr "/Applications/UnPack.app" 2>/dev/null || true

# Compute SHA256 Checksums
echo "==> Computing SHA-256 Checksums..."
DMG_SHA256=$(shasum -a 256 "${DESKTOP_DIR}/${DMG_NAME}" | cut -d ' ' -f 1)
ZIP_SHA256=$(shasum -a 256 "${DESKTOP_DIR}/UnPack-${VERSION}.zip" | cut -d ' ' -f 1)

cat << EOF > "${DESKTOP_DIR}/SHA256_KONTROL.txt"
=====================================================
          UnPack ${VERSION} - SHA-256 Doğrulama Kodları
=====================================================

UnPack-${VERSION}.dmg:
${DMG_SHA256}

UnPack-${VERSION}.zip:
${ZIP_SHA256}

Doğrulamak için Terminal'de çalıştırın:
shasum -a 256 UnPack-${VERSION}.dmg
EOF

# Sync to DESKTOP_KURULUM_DIR
if [ -d "${DESKTOP_KURULUM_DIR}" ]; then
    echo "==> Syncing to ${DESKTOP_KURULUM_DIR}..."
    cp -f "${DESKTOP_DIR}/${DMG_NAME}" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/${APP_NAME}.dmg" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/UnPack-${VERSION}.zip" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/Hızlı_Kurulum.command" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/Kurulum_Rehberi.txt" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/BENİ_OKU_VE_KURULUM.md" "${DESKTOP_KURULUM_DIR}/"
    cp -f "${DESKTOP_DIR}/SHA256_KONTROL.txt" "${DESKTOP_KURULUM_DIR}/"
    rm -rf "${DESKTOP_KURULUM_DIR}/UnPack.app"
    cp -R "${BUILD_DIR}/UnPack.app" "${DESKTOP_KURULUM_DIR}/UnPack.app"
    xattr -cr "${DESKTOP_KURULUM_DIR}" 2>/dev/null || true
fi

# Clean temporary files & strip quarantine from desktop distribution
rm -f "${DESKTOP_DIR}/.DS_Store" 2>/dev/null || true
xattr -cr "${DESKTOP_DIR}" 2>/dev/null || true

echo "==> DMG created successfully at: ${DMG_PATH}"
echo "==> Desktop distribution updated at: ${DESKTOP_DIR}"
echo "==> DMG File Size: $(du -sh "${DMG_PATH}" | cut -f1)"
echo "==> SHA-256 Checksum: ${DMG_SHA256}"
