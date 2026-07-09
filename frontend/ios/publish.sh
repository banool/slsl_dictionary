#!/bin/bash
#
# Build and upload the iOS app to TestFlight using xcodebuild and the
# App Store Connect API key. Uses automatic signing with cloud-managed
# certificates so no manual cert/profile management is needed.

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR/.."

. ./ios/publish.env

[[ -z "${TEAM_ID:-}" ]] && echo 'Please set TEAM_ID' && exit 1
[[ -z "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ]] && echo 'Please set APP_STORE_CONNECT_API_ISSUER_ID' && exit 1
[[ -z "${API_KEY_PATH:-}" ]] && echo 'Please set API_KEY_PATH' && exit 1
[[ ! -f "$API_KEY_PATH" ]] && echo "API key not found at $API_KEY_PATH" && exit 1

# The key ID is NOT stored inside the .p8 — Apple only encodes it in the
# download filename "AuthKey_<ID>.p8". Derive it from that filename when the key
# keeps Apple's name, otherwise fall back to APP_STORE_CONNECT_API_KEY_ID from
# publish.env. (So you can drop that env var entirely by keeping the key named
# AuthKey_<ID>.p8.)
_kf="$(basename "$API_KEY_PATH")"
if [[ "$_kf" == AuthKey_*.p8 ]]; then
  _kf="${_kf#AuthKey_}"
  APP_STORE_CONNECT_API_KEY_ID="${_kf%.p8}"
fi
if [[ -z "${APP_STORE_CONNECT_API_KEY_ID:-}" ]]; then
  echo "Set APP_STORE_CONNECT_API_KEY_ID in ios/publish.env, or name the key file AuthKey_<ID>.p8" >&2
  exit 1
fi

# --beta: after uploading, also promote this build to the external tester group.
# The flag is parsed and the notes prompted up front so the prompt doesn't
# interrupt the long build/upload.
BETA=false
for arg in "$@"; do
  case "$arg" in
    --beta) BETA=true ;;
    *) echo "Unknown argument: $arg (only --beta is supported)" >&2; exit 1 ;;
  esac
done

BETA_GROUP="SLSL Testers"
BETA_NOTES=""
if [[ "$BETA" == true ]]; then
  echo "==> --beta: this build will be sent to the '$BETA_GROUP' external group after upload."
  echo "    External testing needs 'What to Test' notes. Type them now, then finish with"
  echo "    an empty line (or Ctrl-D):"
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      break
    fi
    BETA_NOTES+="$line"$'\n'
  done
  BETA_NOTES="${BETA_NOTES%$'\n'}"
  if [[ -z "$BETA_NOTES" ]]; then
    echo "No 'What to Test' notes entered — aborting." >&2
    exit 1
  fi
fi

ARCHIVE_PATH="build/ios/Runner.xcarchive"
EXPORT_PATH="build/ios/ipa"

echo "==> Cleaning build artifacts..."
flutter clean
flutter pub get

echo "==> Building Flutter app..."
flutter build ios --release --no-codesign

echo "==> Archiving with automatic signing..."
xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_KEY_PATH" \
  -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID"

echo "==> Exporting IPA..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ios/ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$API_KEY_PATH" \
  -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID"

# https://github.com/flutter/flutter/issues/166367
echo "==> Stripping ._Symbols from IPA if present..."
IPA_FILE=$(ls "$EXPORT_PATH"/*.ipa 2>/dev/null | head -1)
if [[ -n "$IPA_FILE" ]]; then
  unzip -l "$IPA_FILE" | grep ._Symbols || true
  zip -d "$IPA_FILE" "._Symbols/" || true
fi

echo "==> Uploading to TestFlight..."
# altool expects AuthKey_<ID>.p8 in a private_keys directory.
PRIVATE_KEYS_DIR="$(pwd)/private_keys"
mkdir -p "$PRIVATE_KEYS_DIR"
ln -sf "$(cd "$(dirname "$API_KEY_PATH")" && pwd)/$(basename "$API_KEY_PATH")" \
  "$PRIVATE_KEYS_DIR/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
xcrun altool --upload-app \
  -f "$EXPORT_PATH"/*.ipa \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"
rm -rf "$PRIVATE_KEYS_DIR"

if [[ "$BETA" == true ]]; then
  echo "==> Promoting the build to the '$BETA_GROUP' external group..."
  # The build number is the +N part of the pubspec version; it identifies the
  # build in App Store Connect.
  BUILD_NUMBER=$(grep -E '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+).*$/\1/')
  ASC_BUNDLE_ID="com.banool.slsldictionary" \
  ASC_BUILD_NUMBER="$BUILD_NUMBER" \
  ASC_GROUP_NAME="$BETA_GROUP" \
  ASC_WHATS_NEW="$BETA_NOTES" \
  APP_STORE_CONNECT_API_KEY_ID="$APP_STORE_CONNECT_API_KEY_ID" \
  APP_STORE_CONNECT_API_ISSUER_ID="$APP_STORE_CONNECT_API_ISSUER_ID" \
  API_KEY_PATH="$API_KEY_PATH" \
  python3 ios/appstore_beta.py
fi

echo "==> Done! Build uploaded to TestFlight."
