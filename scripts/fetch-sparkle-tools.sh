#!/bin/zsh
set -euo pipefail

SPARKLE_VERSION="2.10.0"
SPARKLE_SHA256="c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"
ROOT="${0:A:h:h}"
TOOLS="$ROOT/tools/sparkle-$SPARKLE_VERSION"

if [[ -x "$TOOLS/bin/sign_update" && -f "$ROOT/tools/Sparkle-$SPARKLE_VERSION.tar.xz" ]] \
  && [[ "$(shasum -a 256 "$ROOT/tools/Sparkle-$SPARKLE_VERSION.tar.xz" | cut -d' ' -f1)" == "$SPARKLE_SHA256" ]]; then
  echo "$TOOLS"
  exit 0
fi
mkdir -p "$TOOLS"
ARCHIVE="$ROOT/tools/Sparkle-$SPARKLE_VERSION.tar.xz"
curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$ARCHIVE"
if [[ "$(shasum -a 256 "$ARCHIVE" | cut -d' ' -f1)" != "$SPARKLE_SHA256" ]]; then
  rm -f "$ARCHIVE"
  echo "El paquete de Sparkle no coincide con el SHA-256 esperado. No se usa." >&2
  exit 1
fi
tar -xJf "$ARCHIVE" -C "$TOOLS"
echo "$TOOLS"
