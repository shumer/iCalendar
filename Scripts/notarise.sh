#!/bin/bash
# Send an .app or a .dmg to Apple's notary service, wait for the answer, staple the ticket.
#
# Usage: NOTARY_KEY_P8=... NOTARY_KEY_ID=... NOTARY_ISSUER_ID=... Scripts/notarise.sh <path>
# NOTARY_KEY_P8 is the base64 of the App Store Connect API key file.
set -euo pipefail

TARGET="$1"
WORK="${RUNNER_TEMP:-$(mktemp -d)}"
KEY="$WORK/notary.p8"
trap 'rm -f "$KEY"' EXIT

# A secret pasted with a trailing newline is the commonest way a right value is wrong: an issuer
# id with a newline on the end is "not a valid UUID", and the message does not say why.
NOTARY_KEY_ID="$(printf '%s' "$NOTARY_KEY_ID" | tr -d '\r\n ')"
NOTARY_ISSUER_ID="$(printf '%s' "$NOTARY_ISSUER_ID" | tr -d '\r\n ')"
printf '%s' "$NOTARY_KEY_P8" | tr -d '\r\n ' | base64 --decode > "$KEY"

SUBMISSION="$TARGET"
if [ -d "$TARGET" ]; then
  # ditto rather than zip: a plain zip flattens symlinks and extended attributes, and the bundle
  # that comes out the other end is not the one that was signed.
  SUBMISSION="$WORK/notarise-$(basename "$TARGET").zip"
  ditto -c -k --keepParent "$TARGET" "$SUBMISSION"
fi

RESULT="$WORK/submission-$(basename "$TARGET").json"
xcrun notarytool submit "$SUBMISSION" \
  --key "$KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" \
  --wait --output-format json > "$RESULT" || true
cat "$RESULT"
ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id",""))' "$RESULT")"
STATUS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' "$RESULT")"
if [ "$STATUS" != "Accepted" ]; then
  # Apple says why in a separate log, and "Invalid" on its own is not a reason.
  [ -n "$ID" ] && xcrun notarytool log "$ID" \
    --key "$KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" || true
  echo "::error::notarisation of $(basename "$TARGET") ended with status '$STATUS'; the log above says why"
  exit 1
fi

xcrun stapler staple "$TARGET"
if [ -d "$TARGET" ]; then
  spctl --assess --type execute --verbose=2 "$TARGET"
else
  spctl --assess --type open --context context:primary-signature --verbose=2 "$TARGET"
fi
