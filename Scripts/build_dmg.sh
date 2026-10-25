#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="UnPack"
VERSION="1.7.1"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
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

# Create release ZIP inside build directory
echo "==> Packaging ${APP_NAME}-${VERSION}.zip..."
(cd "${BUILD_DIR}" && zip -rq "${BUILD_DIR}/${APP_NAME}-${VERSION}.zip" "${APP_NAME}.app")

# Compute SHA256 Checksums
echo "==> Computing SHA-256 Checksums..."
DMG_SHA256=$(shasum -a 256 "${DMG_PATH}" | cut -d ' ' -f 1)
ZIP_SHA256=$(shasum -a 256 "${BUILD_DIR}/${APP_NAME}-${VERSION}.zip" | cut -d ' ' -f 1)

echo "==> DMG created successfully at: ${DMG_PATH} (${DMG_SHA256})"
echo "==> ZIP created successfully at: ${BUILD_DIR}/${APP_NAME}-${VERSION}.zip (${ZIP_SHA256})"
echo "==> DMG File Size: $(du -sh "${DMG_PATH}" | cut -f1)"
echo "==> Build complete! Ready for GitHub release."
