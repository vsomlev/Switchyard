#!/bin/bash
# Build Switchyard.app from Sources/main.swift using swiftc (no Xcode project needed).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Switchyard"
BUILD_DIR="build"
APP="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP}/Contents/MacOS"
RES_DIR="${APP}/Contents/Resources"

echo "==> Cleaning previous build"
rm -rf "${APP}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"

echo "==> Compiling Swift"
swiftc -O \
    -framework AppKit \
    -o "${MACOS_DIR}/${APP_NAME}" \
    Sources/main.swift

echo "==> Copying Info.plist"
cp Resources/Info.plist "${APP}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "${RES_DIR}/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" \
        "${APP}/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> Ad-hoc code signing (keeps Automation permission stable)"
codesign --force --deep --sign - "${APP}"

echo "==> Done: ${APP}"
