#!/bin/zsh
set -euo pipefail

SRC="${1:?uso: build-adapter.sh <ruta a mediaremote-adapter> <dir salida>}"
OUT="${2:?uso: build-adapter.sh <ruta a mediaremote-adapter> <dir salida>}"
FW="$OUT/MediaRemoteAdapter.framework"

rm -rf "$FW"
mkdir -p "$FW/Versions/A/Resources" "$FW/Versions/A/Headers"

clang -arch arm64 -dynamiclib -fobjc-arc -fvisibility=default \
  -I"$SRC/include" -I"$SRC/src" \
  "$SRC"/src/adapter/*.m "$SRC/src/private/MediaRemote.m" "$SRC"/src/utility/*.m \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
  -o "$FW/Versions/A/MediaRemoteAdapter"

cp "$SRC/include/MediaRemoteAdapter.h" "$FW/Versions/A/Headers/"
cat > "$FW/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>0.1.0</string>
</dict></plist>
PLIST

ln -sfn A "$FW/Versions/Current"
for item in MediaRemoteAdapter Resources Headers; do
  ln -sfn "Versions/Current/$item" "$FW/$item"
done
codesign --force --deep --sign - "$FW"

clang -arch arm64 -fobjc-arc -Wno-gnu-folding-constant -I"$SRC/src/test" \
  "$SRC/src/test/main.m" "$SRC/src/test/NowPlayingTest.m" \
  -framework Foundation -framework MediaPlayer \
  -o "$OUT/MediaRemoteAdapterTestClient"

cp "$SRC/bin/mediaremote-adapter.pl" "$OUT/"
echo "OK -> $OUT"
