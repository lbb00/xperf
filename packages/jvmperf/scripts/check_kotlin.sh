#!/usr/bin/env bash
# Compile and run the Kotlin examples with Kotlin 2.4. Usage: check_kotlin.sh [log].
set -u
LOG=${1:-/dev/stdout}
case $LOG in /*) ;; *) LOG="$(pwd)/$LOG" ;; esac
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/../examples/kotlin"
. "$SCRIPT_DIR/env.sh"
OUT=$(mktemp -d); pass=0; fail=0
exec 3>&1
{
for f in K*.kt; do
  pkg=$(sed -n 's/^package //p' "$f"); cls="$pkg.$(basename "$f" .kt | sed 's/^\(.\)/\U\1/')Kt"
  cp="$KX_CP"
  d="$OUT/${f%.kt}"; mkdir -p "$d"
  if ! kotlinc -jvm-target 25 -Werror -cp "$cp" -d "$d" "$f" >"$d.err" 2>&1; then
    echo "FAIL (kotlinc) $f"; cat "$d.err"; fail=$((fail+1)); continue
  fi
  if out=$(java -cp "$d:$cp:$KOTLIN_STDLIB" "$cls" 2>&1); then echo "PASS (kotlinc+run) $f: $(echo "$out" | tail -1)"; pass=$((pass+1));
  else echo "FAIL (run) $f"; echo "$out"; fail=$((fail+1)); fi
done
echo "Kotlin: $pass passed, $fail failed"
} | tee "$LOG"
rm -rf "$OUT"
! grep -q "^FAIL" "$LOG" 2>/dev/null
