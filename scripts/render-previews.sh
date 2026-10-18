#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
export NOTCHY_PREVIEW_DIR="$ROOT/preview"
"$ROOT/scripts/test.sh" --filter PanelPreviewRender
ls "$NOTCHY_PREVIEW_DIR"
