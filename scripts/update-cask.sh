#!/bin/zsh
set -euo pipefail

VERSION="${1:?uso: update-cask.sh <versión>}"
ROOT="${0:A:h:h}"
CASK="$ROOT/packaging/homebrew/Casks/notchy.rb"
CHECKSUM="$ROOT/dist/Notchy-$VERSION.zip.sha256"

[[ -f "$CHECKSUM" ]] || { echo "No existe $CHECKSUM. Ejecuta antes ./scripts/release.sh $VERSION"; exit 1; }
SHA=$(cut -d' ' -f1 "$CHECKSUM")
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
grep -E '^  (version|sha256) ' "$CASK"
