#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
MODULE_CACHE="${PROJECT_DIR}/scratch/ModuleCache"

mkdir -p "${BUILD_DIR}"
mkdir -p "${MODULE_CACHE}"

if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
else
    SDK_PATH="$(xcrun --show-sdk-path)"
fi
echo "==> Using SDK: ${SDK_PATH}"

# Find all Swift source files
SWIFT_FILES=($(find "${PROJECT_DIR}/Sources" -name "*.swift" | sort))
echo "==> Found ${#SWIFT_FILES[@]} Swift source files."

echo "==> Compiling UnPack for Apple Silicon (arm64)..."
swiftc \
    -parse-as-library \
    -sdk "${SDK_PATH}" \
    -target arm64-apple-macosx14.0 \
    -module-cache-path "${MODULE_CACHE}" \
    -O \
    "${SWIFT_FILES[@]}" \
    -o "${BUILD_DIR}/UnPack_arm64"

echo "==> Compiling UnPack for Intel (x86_64)..."
swiftc \
    -parse-as-library \
    -sdk "${SDK_PATH}" \
    -target x86_64-apple-macosx14.0 \
    -module-cache-path "${MODULE_CACHE}" \
    -O \
    "${SWIFT_FILES[@]}" \
    -o "${BUILD_DIR}/UnPack_x86_64"

echo "==> Creating Universal Binary for UnPack..."
lipo -create "${BUILD_DIR}/UnPack_arm64" "${BUILD_DIR}/UnPack_x86_64" -o "${BUILD_DIR}/UnPack"
rm -f "${BUILD_DIR}/UnPack_arm64" "${BUILD_DIR}/UnPack_x86_64"

echo "==> Compiling UnPackFinderSync (arm64 & x86_64)..."
swiftc \
    -emit-library \
    -sdk "${SDK_PATH}" \
    -target arm64-apple-macosx14.0 \
    -module-name UnPackFinderSync \
    -module-cache-path "${MODULE_CACHE}" \
    -O \
    "${PROJECT_DIR}/Sources/FinderSync/FinderSync.swift" \
    -o "${BUILD_DIR}/UnPackFinderSync_arm64"

swiftc \
    -emit-library \
    -sdk "${SDK_PATH}" \
    -target x86_64-apple-macosx14.0 \
    -module-name UnPackFinderSync \
    -module-cache-path "${MODULE_CACHE}" \
    -O \
    "${PROJECT_DIR}/Sources/FinderSync/FinderSync.swift" \
    -o "${BUILD_DIR}/UnPackFinderSync_x86_64"

lipo -create "${BUILD_DIR}/UnPackFinderSync_arm64" "${BUILD_DIR}/UnPackFinderSync_x86_64" -o "${BUILD_DIR}/UnPackFinderSync"
rm -f "${BUILD_DIR}/UnPackFinderSync_arm64" "${BUILD_DIR}/UnPackFinderSync_x86_64"

echo "==> Universal compilation successful: ${BUILD_DIR}/UnPack and ${BUILD_DIR}/UnPackFinderSync"
