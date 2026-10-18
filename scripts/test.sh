#!/bin/zsh
set -uo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
for attempt in 1 2 3; do
  output="$(swift test -j 1 "$@" 2>&1 | perl -pe 's/\e\[[0-9;]*m//g')"
  if [[ "$output" != *"plugin for module 'TestingMacros' not found"* ]]; then
    print -r -- "$output" | grep -E "error:|✘|Test run with"
    [[ "$output" == *"✔ Test run with"* && "$output" != *"✘ Test run with"* ]] && exit 0
    exit 1
  fi
  echo "Plugin de macros no disponible (intento $attempt), reintentando…"
done
exit 1
