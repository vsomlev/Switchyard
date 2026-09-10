#!/bin/bash
# Build Switchyard.app from Sources/main.swift using swiftc (no Xcode project needed).
# The app icon is an Icon Composer bundle (switchyard-v1.icon) compiled with actool,
# which ships inside Xcode (26+). swiftc itself works with the Command Line Tools.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Switchyard"
ICON_SRC="Resources/switchyard-v1.icon"
ICON_NAME="switchyard-v1"     # base name -> switchyard-v1.icns + CFBundleIconName
BUILD_DIR="build"
APP="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP}/Contents/MacOS"
RES_DIR="${APP}/Contents/Resources"
PLIST="${APP}/Contents/Info.plist"

# Find an actool that can compile an Icon Composer .icon. The Command Line Tools
# don't ship actool, and older Xcode (e.g. 26.6) crashes on newer .icon files, so
# prefer the newest Xcode found on the system.
find_actool() {
    local best="" bestver=-1 x a v
    for x in /Applications/Xcode*.app "$HOME"/Downloads/Xcode*.app \
             $(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null); do
        [ -d "$x" ] || continue
        a="$x/Contents/Developer/usr/bin/actool"
        [ -x "$a" ] || continue
        v=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
                "$x/Contents/version.plist" 2>/dev/null | awk -F. '{printf "%d%02d", $1, $2}')
        v=${v:-0}
        if [ "$v" -gt "$bestver" ]; then bestver=$v; best=$a; fi
    done
    echo "$best"
}

echo "==> Cleaning previous build"
rm -rf "${APP}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"

echo "==> Compiling Swift"
swiftc -O \
    -framework AppKit \
    -o "${MACOS_DIR}/${APP_NAME}" \
    Sources/main.swift

echo "==> Copying Info.plist"
cp Resources/Info.plist "${PLIST}"

echo "==> Compiling app icon"
if [ -d "${ICON_SRC}" ]; then
    ACTOOL="$(find_actool)"
    if [ -n "${ACTOOL}" ] && DEVELOPER_DIR="${ACTOOL%/usr/bin/actool}" "${ACTOOL}" "${ICON_SRC}" \
            --compile "${RES_DIR}" \
            --app-icon "${ICON_NAME}" \
            --platform macosx \
            --minimum-deployment-target 26.0 \
            --target-device mac \
            --output-partial-info-plist "${BUILD_DIR}/icon-partial.plist" \
            --errors --warnings >/dev/null 2>&1; then
        echo "    icon compiled with ${ACTOOL}"
    else
        echo "    WARNING: could not compile the icon — building without a custom one."
        echo "             Needs Xcode 26+ (actool). Older actool may crash on newer .icon files."
    fi
else
    echo "    WARNING: ${ICON_SRC} not found — building without a custom icon."
fi

echo "==> Ad-hoc code signing (keeps Automation permission stable)"
codesign --force --deep --sign - "${APP}"

echo "==> Done: ${APP}"
