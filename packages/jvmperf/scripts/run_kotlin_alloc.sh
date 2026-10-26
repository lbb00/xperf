#!/usr/bin/env sh
# Compile and bench K13/K14 (ThreadMXBean alloc + time).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export JVMPERF_LIB_DIR="${JVMPERF_LIB_DIR:-$ROOT/lib}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
export JAVA_HOME
PATH="$JAVA_HOME/bin:$PATH"
export PATH
# shellcheck disable=SC1091
. "$ROOT/scripts/env.sh"

RES_DIR="${JMH_RESULTS_DIR:-$ROOT/research/bench-results}"
OUT="$ROOT/examples/kotlin/.k-alloc-build"
mkdir -p "$OUT" "$RES_DIR"

STDLIB="${KOTLIN_STDLIB}"
FILTER="${1:-phase4}"

run_one() {
  base="$1"
  file="$ROOT/examples/kotlin/${base}.kt"
  pkg=$(sed -n 's/^package //p' "$file")
  cls="${pkg}.${base}Kt"
  d="$OUT/$base"
  rm -rf "$d"
  mkdir -p "$d"
  echo "== kotlinc $base =="
  kotlinc -jvm-target 25 -cp "$KX_CP" -d "$d" "$file"
  jsonl="$RES_DIR/${base}.jsonl"
  echo "== bench $base =="
  java -XX:+UseCompactObjectHeaders \
    -cp "$d:$KX_CP:$STDLIB" "$cls" --bench "$jsonl"
  echo "wrote $jsonl"
}

case "$FILTER" in
  K13*|seq*|Seq*) run_one K13_SequenceAlloc ;;
  K14*|lambda*|Lambda*|copy*|Copy*) run_one K14_LambdaCopyAlloc ;;
  K15*|value*|Value*|box*|Box*) run_one K15_ValueClassBoxing ;;
  phase4|all|.)
    run_one K13_SequenceAlloc
    run_one K14_LambdaCopyAlloc
    run_one K15_ValueClassBoxing
    ;;
  *)
    echo "unknown filter: $FILTER" >&2
    exit 1
    ;;
esac
