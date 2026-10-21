#!/bin/zsh
set -euo pipefail

USAGE='uso: measure-energy.sh [--check video|gif|visualizer]… "<escenario>" [segundos]'
CHECKS=()
while [[ "${1:-}" == --check ]]; do
  [[ "${2:-}" == (video|gif|visualizer) ]] || { echo "$USAGE"; exit 1; }
  CHECKS+=("$2")
  shift 2
done
SCENARIO="${1:?$USAGE}"
SECONDS_TOTAL="${2:-60}"
INTERVAL=5
ROOT="${0:A:h:h}"
REPORT="$ROOT/docs/ENERGIA.md"
PROBE_GAP=1.5

probe() {
  local since
  since=$(date '+%Y-%m-%d %H:%M:%S')
  osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("com.danirubio.notchy.playback-probe", $(), $(), true)' >/dev/null
  sleep 0.5
  /usr/bin/log show --start "$since" --style compact \
    --predicate 'subsystem == "com.danirubio.notchy" AND category == "probe"' \
    | grep -o 'playback.*' | tail -1 | sed 's/^playback *//'
}

playing() {
  local kind="$1" first second
  first=$(probe)
  sleep $PROBE_GAP
  second=$(probe)
  python3 -I -c "
import sys
def parse(line):
    return dict(item.rsplit(':', 1) for item in line.split() if ':' in item)
kind, first, second = sys.argv[1], parse(sys.argv[2]), parse(sys.argv[3])
moving = [key for key in first if key.startswith(kind + '#') and key in second and first[key] != second[key]]
print(f'  {kind}: {first} → {second}')
sys.exit(0 if moving else 1)
" "$kind" "$first" "$second"
}

check_playback() {
  local moment="$1" kind
  for kind in "${CHECKS[@]}"; do
    if ! playing "$kind"; then
      echo "MEDICIÓN NO VÁLIDA: $kind no avanza $moment de medir. Repite la medición."
      exit 2
    fi
  done
}

APP_PID=$(pgrep -x Notchy) || { echo "Notchy no está abierta"; exit 1; }
ADAPTER_PID=$(pgrep -f "Notchy.app.*mediaremote-adapter.pl.*stream" || true)
PIDS=(-pid "$APP_PID")
[[ -n "$ADAPTER_PID" ]] && PIDS+=(-pid "$ADAPTER_PID")
SAMPLES=$(( SECONDS_TOTAL / INTERVAL ))

(( ${#CHECKS[@]} )) && { echo "Comprobando que se reproduce: ${CHECKS[*]}"; check_playback antes; }
echo "Midiendo «$SCENARIO» durante ${SECONDS_TOTAL}s…"
RESULT=$(top -l $(( SAMPLES + 1 )) -s $INTERVAL "${PIDS[@]}" -stats pid,command,cpu,idlew,power,mem 2>&1 \
  | grep -E "^($APP_PID|${ADAPTER_PID:-0}) " | tail -$(( SAMPLES * ${#PIDS[@]} / 2 )) \
  | python3 -I -c "
import sys, collections
rows = collections.defaultdict(list)
for line in sys.stdin:
    f = line.split()
    rows[f[1]].append((float(f[2]), int(f[3].rstrip('+')), float(f[4]), f[5]))
for name, values in rows.items():
    cpu = [v[0] for v in values]
    power = [v[2] for v in values]
    wakes = values[-1][1] - values[0][1]
    span = len(values) * $INTERVAL
    print(f'| $SCENARIO | {name} | {sum(cpu)/len(cpu):.2f} % | {max(cpu):.1f} % | {sum(power)/len(power):.2f} | {wakes} en {span} s | {values[-1][3]} |')
")
(( ${#CHECKS[@]} )) && { check_playback después; RESULT=${RESULT//"| $SCENARIO |"/"| $SCENARIO (avanza: ${CHECKS[*]}) |"}; }
echo "$RESULT"
echo "$RESULT" >> "$REPORT"
echo "Añadido a $REPORT"
