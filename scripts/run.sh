#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
"$ROOT/scripts/build-app.sh"
APP="$ROOT/build/Notchy.app"
pkill -x "$(basename "$APP" .app)" 2>/dev/null || true
open "$APP"
