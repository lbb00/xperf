#!/usr/bin/env sh
# Compile and run J31 primitive-map JOL GraphLayout sizes (COH + default headers).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="${JVMPERF_LIB_DIR:-$ROOT/lib}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
export JAVA_HOME
PATH="$JAVA_HOME/bin:$PATH"
export PATH

RES_DIR="${JMH_RESULTS_DIR:-$ROOT/research/bench-results}"
OUT="$ROOT/examples/java/.j31-build"
SRC="$ROOT/examples/java/J31_PrimitiveMapsJol.java"
mkdir -p "$OUT" "$RES_DIR"

STDLIB="${KOTLIN_STDLIB:-}"
if [ -z "$STDLIB" ]; then
  KOTLINC_BIN=$(command -v kotlinc)
  KOTLINC_REAL=$(readlink -f "$KOTLINC_BIN" 2>/dev/null || echo "$KOTLINC_BIN")
  STDLIB="$(dirname "$KOTLINC_REAL")/../lib/kotlin-stdlib.jar"
fi
CP="$LIB/jol-core-0.17.jar:$LIB/fastutil-core-8.5.19.jar:$LIB/eclipse-collections-13.0.0.jar:$LIB/eclipse-collections-api-13.0.0.jar:$LIB/collection-jvm-1.7.0.jar:$LIB/annotation-jvm-1.9.1.jar:$LIB/jspecify-1.0.0.jar:$STDLIB"

echo "== javac J31 =="
rm -rf "$OUT"/*
javac --release 25 -cp "$CP" -d "$OUT" "$SRC"

run_mode() {
  mode="$1"
  shift
  jsonl="$RES_DIR/J31_PrimitiveMapsJol.${mode}.jsonl"
  txt="$RES_DIR/J31_PrimitiveMapsJol.${mode}.txt"
  echo "== J31 $mode =="
  java -Djdk.attach.allowAttachSelf=true "$@" -Djvmperf.coh=$( [ "$mode" = coh ] && echo true || echo false ) \
    -cp "$OUT:$CP" J31_PrimitiveMapsJol "$jsonl" "$txt"
}

run_mode coh -XX:+UseCompactObjectHeaders
run_mode default

# Merge COH rows first (primary Evidence), then default, into canonical name.
{
  cat "$RES_DIR/J31_PrimitiveMapsJol.coh.jsonl"
  cat "$RES_DIR/J31_PrimitiveMapsJol.default.jsonl"
} > "$RES_DIR/J31_PrimitiveMapsJol.jsonl"
cp "$RES_DIR/J31_PrimitiveMapsJol.coh.txt" "$RES_DIR/J31_PrimitiveMapsJol.txt"
echo "wrote $RES_DIR/J31_PrimitiveMapsJol.jsonl"
