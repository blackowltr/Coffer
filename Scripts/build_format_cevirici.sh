#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
MODULE_CACHE="${PROJECT_DIR}/scratch/ModuleCache"
APP_NAME="FormatCevirici"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

mkdir -p "${BUILD_DIR}"
mkdir -p "${MODULE_CACHE}"

echo "==> Apple Silicon (arm64) için Format Dönüştürücü derleniyor..."

# FormatCevirici altındaki tüm Swift dosyalarını bul
SWIFT_FILES=($(find "${PROJECT_DIR}/FormatCevirici" -name "*.swift" | sort))

echo "==> ${#SWIFT_FILES[@]} adet Swift kaynak dosyası bulundu."

swiftc \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -module-cache-path "${MODULE_CACHE}" \
    -O \
    "${SWIFT_FILES[@]}" \
    -o "${BUILD_DIR}/${APP_NAME}"

echo "==> Derleme tamamlandı: ${BUILD_DIR}/${APP_NAME}"

# App Bundle oluşturma
echo "==> ${APP_NAME}.app paketi hazırlanıyor..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cp "${PROJECT_DIR}/FormatCevirici/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "${BUILD_DIR}/AppIcon.icns" ]; then
    cp "${BUILD_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> Ad-hoc kod imzası uygulanıyor..."
codesign -s - --force --deep "${APP_BUNDLE}"

echo "==> Format Dönüştürücü başarıyla oluşturuldu: ${APP_BUNDLE}"
