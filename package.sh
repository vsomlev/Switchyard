#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="build/Switchyard.app"
DIST="dist"
DMG="$DIST/Switchyard.dmg"
ZIP="$DIST/Switchyard.zip"

echo "==> Building app"
./build.sh >/dev/null

echo "==> Preparing dist"
rm -rf "$DIST"; mkdir -p "$DIST"

echo "==> Creating $ZIP"
# ditto preserves the bundle structure and code signature.
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Creating $DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"     # drag-to-install target
hdiutil create -volname "Switchyard" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Done:"
ls -lh "$DIST"
