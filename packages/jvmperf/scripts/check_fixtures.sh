#!/usr/bin/env bash
# Compile the linter fixtures. Android fixtures require android.jar.
set -u
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/../jvmperf-lint/fixtures"
. "$SCRIPT_DIR/env.sh"
: "${ANDROID_JAR:?Set ANDROID_JAR or ANDROID_HOME to compile Android fixtures}"
OUT=$(mktemp -d); pass=0; fail=0
for f in bad/*.java good/*.java ignore.java; do
  d="$OUT/$(echo $f | tr / _)"; mkdir -p "$d"
  if javac --release 25 -nowarn -cp "$ANDROID_JAR" -d "$d" "$f" >"$d.err" 2>&1; then pass=$((pass+1)); echo "PASS javac $f"; else fail=$((fail+1)); echo "FAIL javac $f"; cat "$d.err"; fi
done
for f in bad/*.kt good/*.kt ignore.kt; do
  d="$OUT/$(echo $f | tr / _)"; mkdir -p "$d"
  if kotlinc -jvm-target 25 -nowarn -cp "$ANDROID_JAR" -d "$d" "$f" >"$d.err" 2>&1; then pass=$((pass+1)); echo "PASS kotlinc $f"; else fail=$((fail+1)); echo "FAIL kotlinc $f"; cat "$d.err"; fi
done
echo "Fixture compilation: $pass passed, $fail failed"
rm -rf "$OUT"
[ $fail = 0 ]
