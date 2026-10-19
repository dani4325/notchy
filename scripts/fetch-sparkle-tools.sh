#!/bin/zsh
set -euo pipefail

SPARKLE_VERSION="2.10.0"
ROOT="${0:A:h:h}"
TOOLS="$ROOT/tools/sparkle-$SPARKLE_VERSION"

[[ -x "$TOOLS/bin/sign_update" ]] && { echo "$TOOLS"; exit 0; }
mkdir -p "$TOOLS"
curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$ROOT/tools/Sparkle-$SPARKLE_VERSION.tar.xz"
tar -xJf "$ROOT/tools/Sparkle-$SPARKLE_VERSION.tar.xz" -C "$TOOLS"
echo "$TOOLS"
