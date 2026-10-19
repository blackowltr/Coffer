#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="Coffer"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
else
    SDK_PATH="$(xcrun --show-sdk-path)"
fi

echo "==> Building ${APP_NAME}.app bundle..."

# Ensure binary is built
if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
    "${PROJECT_DIR}/Scripts/build.sh"
fi

# Ensure AppIcon is copied from master Resources
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp -f "${PROJECT_DIR}/Resources/AppIcon.icns" "${BUILD_DIR}/AppIcon.icns"
fi

# Ensure specialized Document Icons (RAR, ZIP, 7Z, TAR.GZ, Archive) are generated
if [ ! -f "${BUILD_DIR}/RarDocIcon.icns" ]; then
    echo "==> Generating document icons (RAR, ZIP, 7Z, TAR.GZ, Archive)..."
    swift -sdk "${SDK_PATH}" -module-cache-path "${PROJECT_DIR}/scratch/ModuleCache" "${PROJECT_DIR}/Scripts/generate_document_icons.swift"
fi

# Clean previous bundle
rm -rf "${APP_BUNDLE}"

# Create bundle directory structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${PROJECT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Copy AppIcon and specialized Document Icons
if [ -f "${BUILD_DIR}/AppIcon.icns" ]; then
    cp "${BUILD_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
for icon in "${BUILD_DIR}"/*DocIcon.icns; do
    if [ -f "${icon}" ]; then
        cp "${icon}" "${APP_BUNDLE}/Contents/Resources/"
    fi
done

# Create PkgInfo
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Bundle FinderSync Extension (.appex) for Top-Level Finder Right-Click Menu
if [ -f "${BUILD_DIR}/CofferFinderSync" ]; then
    echo "==> Bundling CofferFinderSync.appex into Contents/PlugIns..."
    APPEX_DIR="${APP_BUNDLE}/Contents/PlugIns/CofferFinderSync.appex"
    mkdir -p "${APPEX_DIR}/Contents/MacOS"
    cp "${BUILD_DIR}/CofferFinderSync" "${APPEX_DIR}/Contents/MacOS/CofferFinderSync"
    chmod +x "${APPEX_DIR}/Contents/MacOS/CofferFinderSync"
    cp "${PROJECT_DIR}/Sources/FinderSync/Info.plist" "${APPEX_DIR}/Contents/Info.plist"
    codesign -s - --force --deep "${APPEX_DIR}"
fi

# Bundle helper binaries (rar & unrar Universal Binaries)
if [ -d "${PROJECT_DIR}/Resources/bin" ]; then
    echo "==> Bundling official rar & unrar into Contents/MacOS and Contents/Resources/bin..."
    mkdir -p "${APP_BUNDLE}/Contents/Resources/bin"
    cp -R "${PROJECT_DIR}/Resources/bin/"* "${APP_BUNDLE}/Contents/Resources/bin/"
    cp -R "${PROJECT_DIR}/Resources/bin/"* "${APP_BUNDLE}/Contents/MacOS/"
    chmod +x "${APP_BUNDLE}/Contents/Resources/bin/"* 2>/dev/null || true
    chmod +x "${APP_BUNDLE}/Contents/MacOS/rar" "${APP_BUNDLE}/Contents/MacOS/unrar" "${APP_BUNDLE}/Contents/MacOS/7zz" 2>/dev/null || true
fi

# Code sign with ad-hoc signature for local execution
echo "==> Applying ad-hoc codesign signature..."
codesign -s - --force --deep "${APP_BUNDLE}"

# Register with macOS LaunchServices so Finder immediately associates .rar, .zip, .7z with Coffer icon
echo "==> Registering with macOS LaunchServices / Finder..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "${LSREGISTER}" ]; then
    "${LSREGISTER}" -f -r -u "${APP_BUNDLE}" || true
    "${LSREGISTER}" -f "${APP_BUNDLE}" || true
fi

# Reset QuickLook and LaunchServices icon cache
echo "==> Updating QuickLook and icon cache..."
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
touch "${APP_BUNDLE}" || true

# Register FinderSync App Extension with macOS PluginKit
echo "==> Registering FinderSync Extension with pluginkit..."
if [ -d "${APPEX_DIR}" ]; then
    pluginkit -a "${APPEX_DIR}" || true
    pluginkit -e use -i com.coffer.app.FinderSync || true
fi

# Update pasteboard services (NSServices / Finder Quick Actions)
echo "==> Updating Finder Services (NSServices)..."
if [ -x "/System/Library/CoreServices/pbs" ]; then
    /System/Library/CoreServices/pbs -update || true
fi

echo "==> Successfully created and registered: ${APP_BUNDLE}"
