#!/bin/zsh
set -uo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
MODE="${1:---full}"
FAILED=0
SELF_FILES=(scripts/check.sh .githooks/commit-msg)

pass() { print "  ✓ $1" }
fail() { print "  ✗ $1"; FAILED=1 }

tracked_text_files() {
  git ls-files --cached --others --exclude-standard | grep -v -x -F -f <(print -l $SELF_FILES) | while read -r f; do
    [[ -f "$f" ]] && grep -Iq . "$f" 2>/dev/null && print -r -- "$f"
  done
}

print "Regla de energía"
PERIODIC=$(grep -rn -E "Timer\.(scheduledTimer|publish)|Timer\(|DispatchSource\.makeTimerSource|CADisplayLink|displayLink\(|repeatForever|while true" Sources --include='*.swift')
[[ -z "$PERIODIC" ]] && pass "sin temporizadores periódicos ni bucles" || fail "temporizador o bucle periódico:\n$PERIODIC"
SLEEP_LOOPS=$(grep -rn -B4 "Task.sleep" Sources --include='*.swift' | grep -E "while |for await|repeat \{")
[[ -z "$SLEEP_LOOPS" ]] && pass "Task.sleep solo de disparo único" || fail "Task.sleep dentro de un bucle:\n$SLEEP_LOOPS"
TIMELINES=$(grep -rln "TimelineView" Sources --include='*.swift' | grep -v -E "Island/ExpandedMusicView.swift|Visualizer/VisualizerView.swift")
[[ -z "$TIMELINES" ]] && pass "TimelineView solo en vistas del panel abierto" || fail "TimelineView fuera del panel abierto: $TIMELINES"

print "APIs privadas"
PRIVATE=$(grep -rn -E "dlopen|dlsym|PrivateFrameworks|NSClassFromString|perform\(Selector|NSSelectorFromString" Sources --include='*.swift')
[[ -z "$PRIVATE" ]] && pass "solo APIs públicas en Sources" || fail "posible API privada:\n$PRIVATE"

print "Rastros de IA"
AI_PATTERN='claude|anthropic|chatgpt|openai|copilot|co-authored-by|generated (by|with)|ai-generated'
DISCLOSURES=(
  "README.md:- **Desarrollo:** Notchy está desarrollada con ayuda de Claude Code."
  "README.en.md:- **Development:** Notchy is developed with the help of Claude Code."
)
AI_HITS=$(tracked_text_files | xargs grep -n -i -E "$AI_PATTERN" 2>/dev/null | perl -pe 's/^([^:]+):\d+:/$1:/' | grep -v -x -F -f <(print -l $DISCLOSURES))
[[ -z "$AI_HITS" ]] && pass "sin menciones en el código ni la documentación" || fail "rastro de IA:\n$AI_HITS"
AI_COMMITS=$(git log --format="%h %B" | grep -i -E "$AI_PATTERN")
[[ -z "$AI_COMMITS" ]] && pass "sin menciones en el historial de commits" || fail "rastro de IA en commits:\n$AI_COMMITS"

print "Secretos"
SECRET_FILES=$(git ls-files --cached | grep -i -E "\.(p12|pfx|pem|key|cer)$|private[-_]key|password|claves")
[[ -z "$SECRET_FILES" ]] && pass "ningún archivo de claves bajo seguimiento" || fail "archivo sensible bajo seguimiento: $SECRET_FILES"
SECRET_CONTENT=$(tracked_text_files | xargs grep -l -E "BEGIN [A-Z ]*PRIVATE KEY" 2>/dev/null)
[[ -z "$SECRET_CONTENT" ]] && pass "ninguna clave privada en el contenido" || fail "clave privada en: $SECRET_CONTENT"

print "Idiomas"
python3 -I scripts/check-localization.py >/dev/null && pass "todos los textos en el catálogo y traducidos" || fail "faltan textos en el catálogo (python3 scripts/check-localization.py)"
python3 -I scripts/tests/test_localization_checks.py >/dev/null 2>&1 && pass "las comprobaciones de idioma detectan sus casos de prueba" || fail "fallan los tests de las comprobaciones (python3 scripts/tests/test_localization_checks.py)"

if [[ "$MODE" == "--full" ]]; then
  print "Compilación y tests"
  BUILD_OUTPUT="$(swift build -j 1 2>&1)"
  [[ "$BUILD_OUTPUT" == *"Build complete"* ]] && pass "compila" || fail "no compila (swift build -j 1)"
  ./scripts/test.sh >/dev/null 2>&1 && pass "tests en verde" || fail "fallan tests (./scripts/test.sh)"
fi

(( FAILED )) && { print "\nHay comprobaciones que fallan."; exit 1 }
print "\nTodo correcto."
