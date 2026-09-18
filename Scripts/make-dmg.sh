#!/bin/bash
# Wrap MenuCal.app in a disk image with a link to /Applications beside it.
#
# Usage: Scripts/make-dmg.sh <MenuCal.app> <output.dmg>
# Signs the image with CODESIGN_IDENTITY when one is set. The app inside must already be signed,
# and stapled if it was notarised: an image built before stapling carries an app without a ticket.
set -euo pipefail

APP="$1"
DMG="$2"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# ditto keeps the signature's extended attributes; cp -R can lose them on some volumes.
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "MenuCal" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

if [ -n "${CODESIGN_IDENTITY:-}" ] && [ "$CODESIGN_IDENTITY" != "-" ]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG"
  codesign --verify --verbose=1 "$DMG"
fi
echo "Built: $DMG"
