#!/usr/bin/env bash
# Compile and run the Java examples with JDK 25. Usage: check_java.sh [log].
set -u
LOG=${1:-/dev/stdout}
case $LOG in /*) ;; *) LOG="$(pwd)/$LOG" ;; esac
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/../examples/java"
. "$SCRIPT_DIR/env.sh"
OUT=$(mktemp -d); pass=0; fail=0
for f in J*.java; do
  c=${f%.java}; jopt=(--release 25); cp="$OUT"; run=()
  case $c in
    J02*) cp="$PRIM_CP:$OUT" ;;
    J31*) cp="$JOL_CP:$PRIM_CP:$JVMPERF_LIB_DIR/collection-jvm-1.7.0.jar:$JVMPERF_LIB_DIR/annotation-jvm-1.9.1.jar:$JVMPERF_LIB_DIR/jspecify-1.0.0.jar:${KOTLIN_STDLIB}:$OUT"; run=(-XX:+UseCompactObjectHeaders -Djdk.attach.allowAttachSelf=true -Djvmperf.coh=true) ;;
    J07*) jopt+=(--add-modules jdk.incubator.vector); run=(--add-modules jdk.incubator.vector) ;;
    J10*) jopt=(--source 25 --add-exports java.base/jdk.internal.vm.annotation=ALL-UNNAMED); run=(-XX:-RestrictContended) ;;
    J19*) cp="$JMH_CP:$OUT" ;;
  esac
  if ! javac "${jopt[@]}" -Xlint:all,-processing,-options,-incubating -Werror -cp "$cp" -d "$OUT" "$f" >"$OUT/err" 2>&1; then
    echo "FAIL (javac) $f"; cat "$OUT/err"; fail=$((fail+1)); continue
  fi
  if [ "$c" = J19_JmhBench ]; then echo "PASS (javac + JMH annotation processor) $f"; pass=$((pass+1)); continue; fi
  if out=$(java "${run[@]}" -cp "$cp" "$c" 2>&1); then echo "PASS (javac+run) $f: $(echo "$out" | grep -v WARNING | tail -1)"; pass=$((pass+1));
  else echo "FAIL (run) $f"; echo "$out"; fail=$((fail+1)); fi
done > >(tee "$LOG") 
wait
echo "Java: $pass passed, $fail failed" | tee -a "$LOG"
rm -rf "$OUT"
[ $fail = 0 ]
