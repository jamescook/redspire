#!/usr/bin/env bash
# Build, codesign, and (optionally) notarize BattlespireLauncher.app.
#
# Usage:
#   ./build.sh                 Build + codesign only (runs locally fine unnotarized).
#   ./build.sh --notarize       Also notarize + staple, for distribution.
#
# One-time setup for --notarize:
#   xcrun notarytool store-credentials "battlespire-notary" \
#     --apple-id "you@example.com" --team-id TEAMID --password "app-specific-password"
#   (Generate the app-specific password at https://appleid.apple.com/account/manage
#   under Sign-In and Security > App-Specific Passwords. Credentials are stored
#   in your keychain, not in this repo.)
set -euo pipefail
cd "$(dirname "$0")"

SIGN_IDENTITY="Developer ID Application: James Cook (3YV2AH67DH)"
NOTARY_PROFILE="battlespire-notary"
APP_NAME="BattlespireLauncher"

DO_NOTARIZE=0
if [ "${1:-}" = "--notarize" ]; then
  DO_NOTARIZE=1
fi

echo "==> Building (release)"
swift build -c release

DIST="dist"
APP="$DIST/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP/Contents/Info.plist"

echo "==> Codesigning ($SIGN_IDENTITY)"
codesign --force --deep --options runtime --timestamp \
  --sign "$SIGN_IDENTITY" "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

if [ "$DO_NOTARIZE" -eq 0 ]; then
  echo "==> Done: $APP (signed, not notarized)"
  echo "    Run './build.sh --notarize' before distributing to others --"
  echo "    otherwise Gatekeeper will quarantine it on first launch."
  exit 0
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "error: no stored notarytool credentials named '$NOTARY_PROFILE'." >&2
  echo "Run this once (see comment at top of this script):" >&2
  echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD" >&2
  exit 1
fi

ZIP="$DIST/$APP_NAME.zip"
echo "==> Zipping for notarization"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"

echo "==> Verifying Gatekeeper acceptance"
spctl -a -vvv -t install "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $APP (notarized) / $ZIP (ready to distribute)"
