#!/bin/zsh
set -euo pipefail

SCENARIO="${1:?uso: measure-energy.sh \"<escenario>\" [segundos]}"
SECONDS_TOTAL="${2:-60}"
INTERVAL=5
ROOT="${0:A:h:h}"
REPORT="$ROOT/docs/ENERGIA.md"

APP_PID=$(pgrep -x Notchy) || { echo "Notchy no está abierta"; exit 1; }
ADAPTER_PID=$(pgrep -f "Notchy.app.*mediaremote-adapter.pl.*stream" || true)
PIDS=(-pid "$APP_PID")
[[ -n "$ADAPTER_PID" ]] && PIDS+=(-pid "$ADAPTER_PID")
SAMPLES=$(( SECONDS_TOTAL / INTERVAL ))

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
echo "$RESULT"
echo "$RESULT" >> "$REPORT"
echo "Añadido a $REPORT"
