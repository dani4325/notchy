#!/bin/zsh
set -euo pipefail

VERSION="${1:?uso: release.sh <versión> [número de build]}"
BUILD="${2:-1}"
ROOT="${0:A:h:h}"
DIST="$ROOT/dist"
APP="$ROOT/build/Notchy.app"
ZIP="$DIST/Notchy-$VERSION.zip"
REPO_URL="${NOTCHY_REPO_URL:-https://github.com/TU_USUARIO/notchy}"

cd "$ROOT"
./scripts/test.sh >/dev/null || { echo "Los tests fallan: no se publica."; exit 1; }
python3 -I scripts/check-localization.py >/dev/null || { echo "Faltan textos en el catálogo: no se publica."; exit 1; }
NOTCHY_VERSION="$VERSION" NOTCHY_BUILD="$BUILD" ./scripts/build-app.sh >/dev/null

codesign --verify --strict --deep "$APP"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]]

mkdir -p "$DIST"
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")

SPARKLE_TOOLS="$(./scripts/fetch-sparkle-tools.sh | tail -1)"
SIGNATURE="$("$SPARKLE_TOOLS/bin/sign_update" --account notchy "$ZIP")"
python3 -I scripts/update-appcast.py "$ROOT/appcast.xml" "$VERSION" "$BUILD" \
  "$REPO_URL/releases/download/v$VERSION/Notchy-$VERSION.zip" "$SIGNATURE" "15.0"

echo "Release lista:"
echo "  $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "  SHA-256: $(cut -d' ' -f1 "$ZIP.sha256")"
echo "  appcast.xml actualizado (firma EdDSA incluida)"
