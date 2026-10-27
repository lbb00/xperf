#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/examples/bench"
cc -std=c11 -O2 -o "$BENCH/cp003_printf_hot" "$BENCH/cp003_printf_hot.c"
"$BENCH/cp003_printf_hot" 80000 9 > "$ROOT/evidence/cp-printf-hot.jsonl"
echo "wrote $ROOT/evidence/cp-printf-hot.jsonl"
