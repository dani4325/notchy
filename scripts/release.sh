#!/bin/zsh
set -euo pipefail

VERSION="${1:?uso: release.sh <versión> <número de build>}"
BUILD="${2:?uso: release.sh <versión> <número de build> (entero que crece en cada versión)}"
ROOT="${0:A:h:h}"
DIST="$ROOT/dist"
APP="$ROOT/build/Notchy.app"
ZIP="$DIST/Notchy-$VERSION.zip"
REPO_URL="${NOTCHY_REPO_URL:-https://github.com/dani4325/notchy}"
FEED_URL="${NOTCHY_FEED_URL:-https://raw.githubusercontent.com/dani4325/notchy/main/appcast.xml}"
SIGN_IDENTITY_NAME="Notchy Self-Signed Code Signing"

cd "$ROOT"
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "El número de build debe ser un entero."; exit 1; }
if [[ "$REPO_URL$FEED_URL" == *TU_USUARIO* && "${NOTCHY_ALLOW_PLACEHOLDER:-0}" != 1 ]]; then
  echo "Las URL aún tienen TU_USUARIO. Define NOTCHY_REPO_URL y NOTCHY_FEED_URL (o NOTCHY_ALLOW_PLACEHOLDER=1 para una prueba local)."
  exit 1
fi
LAST_BUILD=$(grep -o '<sparkle:version>[0-9]*' appcast.xml 2>/dev/null | grep -o '[0-9]*$' | sort -n | tail -1)
if [[ -n "$LAST_BUILD" ]] && ! grep -q "<sparkle:shortVersionString>$VERSION<" appcast.xml && (( BUILD <= LAST_BUILD )); then
  echo "El build $BUILD no es mayor que el último publicado ($LAST_BUILD): Sparkle no ofrecería la actualización."
  exit 1
fi
IDENTITIES="$(security find-identity -p codesigning)"
[[ "$IDENTITIES" == *"$SIGN_IDENTITY_NAME"* ]] || {
  echo "No está el certificado «$SIGN_IDENTITY_NAME» en el llavero: la release saldría con otra firma. Restáuralo (docs/PUBLICAR.md)."
  exit 1
}
./scripts/test.sh >/dev/null || { echo "Los tests fallan: no se publica."; exit 1; }
python3 -I scripts/check-localization.py >/dev/null || { echo "Faltan textos en el catálogo: no se publica."; exit 1; }
NOTCHY_VERSION="$VERSION" NOTCHY_BUILD="$BUILD" NOTCHY_FEED_URL="$FEED_URL" ./scripts/build-app.sh >/dev/null

codesign --verify --strict --deep "$APP"
SIGNATURE_INFO="$(codesign -dvv "$APP" 2>&1)"
[[ "$SIGNATURE_INFO" == *"Authority=$SIGN_IDENTITY_NAME"* ]] || { echo "La app no está firmada con «$SIGN_IDENTITY_NAME»."; exit 1; }
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
