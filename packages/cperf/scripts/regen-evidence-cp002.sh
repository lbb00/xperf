#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/examples/bench"
cc -std=c11 -O2 -o "$BENCH/cp002_realloc_growth" "$BENCH/cp002_realloc_growth.c"
"$BENCH/cp002_realloc_growth" 100000 9 > "$ROOT/evidence/cp-realloc-grow-one.jsonl"
echo "wrote $ROOT/evidence/cp-realloc-grow-one.jsonl"
