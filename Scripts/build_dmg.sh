#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="UnPack"
VERSION="1.8.0"
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
          UnPack - Kolay Kurulum Rehberi
=====================================================

YÖNTEM 1 (ÖNERİLEN - TEK TIKLA OTOMATİK KURULUM):
1. Bu penceredeki "Hızlı_Kurulum.command" dosyasına ÇİFT TIKLAYIN.
   (macOS "Açmak istediğinizden emin misiniz?" diye sorarsa "Aç" butonuna basın.)
2. Terminal açılacak; UnPack'i otomatik olarak Uygulamalar'a taşıyacak,
   macOS "Zararlı dosya / Çöpe taşı" güvenlik engelini kaldıracak ve
   uygulamayı doğrudan başlatacaktır.

-----------------------------------------------------

YÖNTEM 2 (Klasik Sürükle - Bırak):
1. "UnPack" uygulamasını "Applications" klasörüne sürükleyin.
2. Açarken "Zararlı dosya / Çöpe taşı" uyarısı çıkarsa:
   -> Sistem Ayarları ➔ Gizlilik ve Güvenlik bölümüne gidin.
   -> Sayfanın en altındaki "Yine de Aç" butonuna basın.
   (VEYA bu penceredeki "Hızlı_Kurulum.command" dosyasına çift tıklayın.)

=====================================================
Tebrikler! UnPack kullanıma hazırdır.
EOF
cp "${BUILD_DIR}/Kurulum_Rehberi.txt" "${STAGING_DIR}/Kurulum_Rehberi.txt"

# Add Hızlı Kurulum.command into DMG and Desktop
cat << 'EOF' > "${BUILD_DIR}/Hızlı_Kurulum.command"
#!/usr/bin/env bash
set -e
clear

echo "====================================================="
echo "        UnPack - Otomatik Kurulum & Güvenlik İzni    "
echo "====================================================="
echo ""
echo "Bu araç UnPack'i Uygulamalar klasörüne kurar ve macOS"
echo "Gatekeeper 'Zararlı dosya' güvenlik engelini kaldırır."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH=""

if [ -d "${SCRIPT_DIR}/UnPack.app" ]; then
    APP_PATH="${SCRIPT_DIR}/UnPack.app"
elif [ -d "/Volumes/UnPack/UnPack.app" ]; then
    APP_PATH="/Volumes/UnPack/UnPack.app"
elif [ -d "/Applications/UnPack.app" ]; then
    APP_PATH="/Applications/UnPack.app"
fi

if [ -z "${APP_PATH}" ] || [ ! -d "${APP_PATH}" ]; then
    echo "❌ HATA: UnPack.app paketi bulunamadı!"
    echo "Lütfen bu dosyayı UnPack DMG penceresi içinde çalıştırın."
    echo ""
    read -p "Çıkmak için Enter'a basın..."
    exit 1
fi

echo "==> [1/3] UnPack.app Uygulamalar (/Applications) klasörüne yerleştiriliyor..."
pkill -x "UnPack" 2>/dev/null || true
if [ "${APP_PATH}" != "/Applications/UnPack.app" ]; then
    rm -rf "/Applications/UnPack.app"
    cp -R "${APP_PATH}" "/Applications/UnPack.app"
fi

echo "==> [2/3] macOS Gatekeeper güvenlik karantinası kaldırılıyor..."
xattr -cr "/Applications/UnPack.app" 2>/dev/null || true
chmod -R 755 "/Applications/UnPack.app" 2>/dev/null || true

echo "==> [3/3] UnPack başlatılıyor..."
open "/Applications/UnPack.app"

echo ""
echo "====================================================="
echo "🎉 Tebrikler! UnPack başarıyla kuruldu ve başlatıldı."
echo "   Güvenlik engeli kaldırıldı, artık doğrudan açılacaktır."
echo "====================================================="
echo ""
sleep 2
exit 0
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
