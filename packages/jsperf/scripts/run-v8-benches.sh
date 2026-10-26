#!/usr/bin/env bash
# Run V8-oriented microbenches; record env + JSONL under $JSPERF_BENCH_OUT (default examples/bench/out).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/examples/bench"
RESEARCH="${JSPERF_BENCH_OUT:-$ROOT/examples/bench/out}"
mkdir -p "$RESEARCH"
NODE_BIN="${NODE_BIN:-node}"
RESULTS="$RESEARCH/results.jsonl"
ENV_OUT="$RESEARCH/env.txt"

{
  echo "ts=$(date -Iseconds)"
  echo "node_bin=$NODE_BIN"
  "$NODE_BIN" -p "'node='+process.version+' v8='+process.versions.v8+' arch='+process.arch+' platform='+process.platform"
  echo "uname=$(uname -a)"
  echo "cwd=$ROOT"
} | tee "$ENV_OUT"

export RESULTS_JSONL="$RESULTS"
: > "$RESULTS"

for f in shape_mono_vs_poly.js elements_packed_vs_holey.js typed_array_vs_number_array.js; do
  echo "=== $f ==="
  "$NODE_BIN" "$BENCH/$f"
  echo
done

echo "JSONL -> $RESULTS"
echo "env   -> $ENV_OUT"
