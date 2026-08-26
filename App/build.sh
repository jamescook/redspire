#!/usr/bin/env bash
# Build, codesign, and (optionally) notarize BattlespireLauncher.app.
#
# Usage:
#   ./build.sh                 Build + codesign only (runs locally fine unnotarized).
#   ./build.sh --notarize       Also notarize + staple, for distribution.
#
# Nothing here is hardcoded to a particular person/team -- everything below
# is an env var with a sensible local default. Override by exporting them
# before running, or by dropping a `.env` file next to this script (gitignored,
# see .env.example) -- it's sourced automatically if present.
#
#   CODESIGN_IDENTITY   "Developer ID Application: ..." string to sign with.
#                        Defaults to auto-detecting the sole such identity in
#                        your keychain (errors out if there's none or more
#                        than one -- set this explicitly in that case).
#   APP_NAME             Defaults to "BattlespireLauncher".
#
# Notarization needs Apple credentials, via ONE of two methods:
#
#   Local/interactive (recommended for your own machine):
#     xcrun notarytool store-credentials "battlespire-notary" \
#       --apple-id "you@example.com" --team-id TEAMID --password "app-specific-password"
#     (Generate the app-specific password at https://appleid.apple.com/account/manage
#     under Sign-In and Security > App-Specific Passwords. Stored in your
#     keychain, never in this repo.)
#     Override the profile name with NOTARY_PROFILE if you used a different one.
#
#   CI / non-interactive (an App Store Connect API key, no keychain needed):
#     Set NOTARY_KEY_PATH (path to the downloaded .p8), NOTARY_KEY_ID, and
#     NOTARY_ISSUER_ID (from https://appstoreconnect.apple.com/access/api).
#     Takes priority over NOTARY_PROFILE when all three are set.
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

APP_NAME="${APP_NAME:-BattlespireLauncher}"
NOTARY_PROFILE="${NOTARY_PROFILE:-battlespire-notary}"

if [ -z "${CODESIGN_IDENTITY:-}" ]; then
  MATCHES=$(security find-identity -v -p codesigning | grep -o '"Developer ID Application:[^"]*"' | tr -d '"' || true)
  COUNT=$(printf '%s\n' "$MATCHES" | grep -c . || true)
  if [ "$COUNT" -eq 1 ]; then
    CODESIGN_IDENTITY="$MATCHES"
  else
    echo "error: couldn't auto-detect a single 'Developer ID Application' identity ($COUNT found)." >&2
    echo "Set CODESIGN_IDENTITY explicitly (env var or App/.env), e.g.:" >&2
    echo "  CODESIGN_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\"" >&2
    exit 1
  fi
fi

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

# SPM's generated resource bundle is an informal folder shape (no Info.plist)
# that codesign refuses to validate as a nested bundle -- rather than fight
# that, just copy the actual resource file(s) into the conventional
# Contents/Resources/ location; see DiscImageInstaller's lookup for the
# matching read side.
RESOURCE_BUNDLE=".build/release/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE"/. "$APP/Contents/Resources/"
fi

echo "==> Codesigning ($CODESIGN_IDENTITY)"
codesign --force --deep --options runtime --timestamp \
  --sign "$CODESIGN_IDENTITY" "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

if [ "$DO_NOTARIZE" -eq 0 ]; then
  echo "==> Done: $APP (signed, not notarized)"
  echo "    Run './build.sh --notarize' before distributing to others --"
  echo "    otherwise Gatekeeper will quarantine it on first launch."
  exit 0
fi

NOTARY_ARGS=()
if [ -n "${NOTARY_KEY_PATH:-}" ] && [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER_ID:-}" ]; then
  echo "==> Using App Store Connect API key for notarization"
  NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
elif xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "==> Using stored keychain profile '$NOTARY_PROFILE' for notarization"
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
else
  echo "error: no notarization credentials found." >&2
  echo "Set up ONE of the two methods described at the top of this script:" >&2
  echo "  Local:  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD" >&2
  echo "  CI:     export NOTARY_KEY_PATH=./AuthKey.p8 NOTARY_KEY_ID=... NOTARY_ISSUER_ID=..." >&2
  exit 1
fi

ZIP="$DIST/$APP_NAME.zip"
echo "==> Zipping for notarization"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP" "${NOTARY_ARGS[@]}" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"

echo "==> Verifying Gatekeeper acceptance"
spctl -a -vvv -t install "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $APP (notarized) / $ZIP (ready to distribute)"
