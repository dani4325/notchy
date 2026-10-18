#!/bin/zsh
set -euo pipefail

APP_NAME="Notchy"
BUNDLE_ID="com.danirubio.notchy"
VERSION="0.1.0"
BUILD_NUMBER="1"
MIN_MACOS="15.0"

ROOT="${0:A:h:h}"
OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"

cd "$ROOT"
swift build -c release --product NotchApp
BIN="$(swift build -c release --show-bin-path)/NotchApp"

ADAPTER_OUT="$(mktemp -d)"
trap 'rm -rf "$ADAPTER_OUT"' EXIT
"$ROOT/scripts/build-adapter.sh" "$ROOT/Vendor/mediaremote-adapter" "$ADAPTER_OUT" >/dev/null

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp -R "$ADAPTER_OUT/MediaRemoteAdapter.framework" "$APP/Contents/Frameworks/"
cp "$ADAPTER_OUT/MediaRemoteAdapterTestClient" "$APP/Contents/MacOS/"
cp "$ADAPTER_OUT/mediaremote-adapter.pl" "$APP/Contents/Resources/"
cp "$ROOT/Vendor/mediaremote-adapter/LICENSE" "$APP/Contents/Resources/MediaRemoteAdapter-LICENSE.txt"
cp -R "$ROOT/Resources/Fonts" "$APP/Contents/Resources/Fonts"
python3 -I "$ROOT/scripts/build-localizations.py" "$ROOT/Resources/Localization" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
<key>CFBundleDisplayName</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
<key>LSUIElement</key><true/>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>NSHighResolutionCapable</key><true/>
<key>UTExportedTypeDeclarations</key><array><dict>
<key>UTTypeIdentifier</key><string>$BUNDLE_ID.theme</string>
<key>UTTypeDescription</key><string>Tema de $APP_NAME</string>
<key>UTTypeConformsTo</key><array><string>public.zip-archive</string></array>
<key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>notchytheme</string></array></dict>
</dict></array>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Tema de $APP_NAME</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Owner</string>
<key>LSItemContentTypes</key><array><string>$BUNDLE_ID.theme</string></array>
</dict></array>
<key>NSAudioCaptureUsageDescription</key><string>$APP_NAME escucha el audio que suena para animar el visualizador del notch. No graba ni guarda nada.</string>
<key>NSAppleEventsUsageDescription</key><string>$APP_NAME lee la canción que suena en Spotify o Música y controla la reproducción cuando MediaRemote no está disponible.</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP/Contents/MacOS/MediaRemoteAdapterTestClient"
codesign --force --sign - "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "OK -> $APP"
