#!/bin/bash
# Build MenuCal.app from the SwiftPM package, signed with a Developer ID when there is one.
#
# The suite runs first: shipping a build with broken core logic is worse than not building.
# Usage: ./build.sh [--skip-tests] [--no-install]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/MenuCal.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
BUNDLE_ID="com.shumenko.menucal"
DEPLOYMENT_TARGET="14.0"

SKIP_TESTS=""
NO_INSTALL=""
for argument in "$@"; do
  case "$argument" in
    --skip-tests) SKIP_TESTS=1 ;;
    --no-install) NO_INSTALL=1 ;;
    *) echo "Unknown option: $argument" >&2; exit 2 ;;
  esac
done

if [ -z "$SKIP_TESTS" ]; then
  echo "Running tests…"
  "$HERE/run-tests.sh" | tail -3
fi

# Version: the marketing number lives in VERSION and is bumped by hand; the build number is
# the commit count, so it always advances and cannot be forgotten.
SHORT_VERSION="$(tr -d '[:space:]' < "$HERE/VERSION" 2>/dev/null || echo 0.0)"
BUILD_NUMBER="$(git -C "$HERE" rev-list --count HEAD 2>/dev/null || echo 1)"
echo "Building v$SHORT_VERSION ($BUILD_NUMBER)…"

# The SDK the app is stamped as built against is what macOS reads to decide which era of chrome
# and materials to draw. SwiftPM writes the deployment target there instead, so an app that runs
# on macOS 14 would be told to look like one built for it. The deployment target is unchanged;
# only the stamp is made honest.
SDK_VERSION="$(xcrun --show-sdk-version 2>/dev/null || echo "$DEPLOYMENT_TARGET")"
swift build --package-path "$HERE" -c release --product MenuCal \
  -Xlinker -platform_version -Xlinker macos -Xlinker "$DEPLOYMENT_TARGET" -Xlinker "$SDK_VERSION"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

# One folder per language, copied as they are; the plist lists whichever exist.
LOCALIZATIONS=""
for folder in "$HERE"/Resources/Localizations/*.lproj; do
  cp -R "$folder" "$RESOURCES/"
  LOCALIZATIONS="$LOCALIZATIONS<string>$(basename "$folder" .lproj)</string>"
done

ICON_KEY=""
if [ -d "$HERE/Resources/AppIcon/MenuCal.iconset" ]; then
  iconutil -c icns "$HERE/Resources/AppIcon/MenuCal.iconset" -o "$RESOURCES/MenuCal.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>MenuCal</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MenuCal</string>
  <key>CFBundleDisplayName</key><string>MenuCal</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>MenuCal</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>$SHORT_VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  $ICON_KEY
  <key>LSMinimumSystemVersion</key><string>$DEPLOYMENT_TARGET</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array>$LOCALIZATIONS</array>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <!-- Agent app: no Dock icon, no application menu. -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

cp "$(swift build --package-path "$HERE" -c release --show-bin-path)/MenuCal" "$MACOS/MenuCal"
chmod +x "$MACOS/MenuCal"

# Signed with an identity when one is named, ad-hoc otherwise. CODESIGN_IDENTITY is the name or
# the SHA-1 of a code-signing identity in the keychain; the release runner passes the SHA-1.
# Hardened runtime and a secure timestamp go with the identity because notarisation requires
# both. Unset, the Developer ID in the keychain is used; CODESIGN_IDENTITY=- asks for ad-hoc on
# purpose.
if [ -z "${CODESIGN_IDENTITY:-}" ]; then
  CODESIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk '/"Developer ID Application:/ { print $2; exit }')"
fi
if [ "${CODESIGN_IDENTITY:-}" = "-" ]; then
  CODESIGN_IDENTITY=""
fi
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=1 "$APP"
  echo "Signed with: $CODESIGN_IDENTITY"
else
  codesign --force --sign - "$APP" 2>/dev/null || echo "(ad-hoc signing skipped)"
fi

echo "Built: $APP"

# Installing is the default. macOS registers the login item by path, and this directory's bundle
# is deleted and recreated on every build, so the copy that actually runs must live in
# /Applications, otherwise a rebuild leaves the old version running.
if [ -n "$NO_INSTALL" ]; then
  echo "Run:   open '$APP'    Quit: pkill -f MenuCal.app/Contents/MacOS/MenuCal"
  exit 0
fi

DEST="/Applications/MenuCal.app"
WAS_RUNNING=""
pgrep -f "MenuCal.app/Contents/MacOS/MenuCal" >/dev/null && WAS_RUNNING=1
pkill -f "MenuCal.app/Contents/MacOS/MenuCal" 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$APP" "$DEST"
open "$DEST"
echo "Installed and launched: $DEST  (v$SHORT_VERSION build $BUILD_NUMBER)"
[ -n "$WAS_RUNNING" ] && echo "Replaced the running instance."
exit 0
