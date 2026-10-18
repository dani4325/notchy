#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
"$ROOT/scripts/build-app.sh"
APP="$(ls -d "$ROOT"/build/*.app | head -1)"
pkill -x "$(basename "$APP" .app)" 2>/dev/null || true
open "$APP"
