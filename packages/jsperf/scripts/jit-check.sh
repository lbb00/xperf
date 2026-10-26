#!/usr/bin/env bash
# Runtime JIT check via --trace-deopt. Not a lint rule.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE_BIN="${NODE_BIN:-node}"
RESEARCH="${JSPERF_BENCH_OUT:-$ROOT/examples/bench/out}"
mkdir -p "$RESEARCH"
PROBE="$ROOT/examples/bench/deopt_probe.js"
OUT="$RESEARCH/deopt-sample.txt"
COMBINED="$RESEARCH/deopt-combined.txt"

{
  echo "# jsperf JIT / deopt sample (runtime harness, not lint)"
  echo "# ts=$(date -Iseconds) (local clock = Asia/Shanghai)"
  echo "# node_bin=$NODE_BIN"
  "$NODE_BIN" -p "'# node='+process.version+' v8='+process.versions.v8"
  echo "#"
  echo "# Command: $NODE_BIN --trace-deopt $PROBE"
  echo "# Static jsperf-lint CANNOT detect IC state, deopts, or optimization tier."
  echo "# Lint = allocation/shape smells. JIT verification = profile / trace / bench."
  echo "#"
} > "$OUT"

set +e
# V8 may print bailout traces on stdout or stderr depending on build — capture both.
"$NODE_BIN" --trace-deopt "$PROBE" >"$RESEARCH/deopt-stdout.txt" 2>"$RESEARCH/deopt-raw.txt"
ec=$?
set -e
cat "$RESEARCH/deopt-stdout.txt" "$RESEARCH/deopt-raw.txt" > "$COMBINED"

{
  echo "===== probe stdout ====="
  cat "$RESEARCH/deopt-stdout.txt"
  echo
  echo "----- --trace-deopt excerpt (bailout / deopt lines) -----"
  if rg -n -i "\[bailout|deopt|not a Smi|wrong map|unexpected" "$COMBINED" >/dev/null 2>&1; then
    rg -n -i "\[bailout|deopt|not a Smi|wrong map|unexpected" "$COMBINED" | head -40
  else
    echo "(no bailout keywords; showing combined head)"
    head -30 "$COMBINED"
  fi
  echo
  echo "----- end excerpt -----"
  echo "# full combined: deopt-combined.txt  stderr-only: deopt-raw.txt  exit=$ec"
} >> "$OUT"

echo "wrote $OUT"
wc -l "$OUT" "$COMBINED"
echo "==== SAMPLE ===="
cat "$OUT"
