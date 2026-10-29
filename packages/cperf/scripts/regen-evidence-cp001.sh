#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/examples/bench"
cc -std=c11 -O2 -o "$BENCH/cp001_malloc_vs_arena" "$BENCH/cp001_malloc_vs_arena.c"
"$BENCH/cp001_malloc_vs_arena" 200000 9 > "$ROOT/evidence/cp-alloc-hot.jsonl"
echo "wrote $ROOT/evidence/cp-alloc-hot.jsonl"
