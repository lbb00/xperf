#!/usr/bin/env bash
# Correlate CP00x static smells with cc -O2 wall time (median of N runs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$ROOT/examples/bench"
PROBES="$BENCH/lint_probes"
OUT_DIR="${CPERF_BENCH_OUT:-$BENCH/build/static-vs-o2}"
LINT_BIN="${LINT_BIN:-$ROOT/cperf-lint/cperf-lint}"
CC_BIN="${CC_BIN:-cc}"
CFLAGS="${CFLAGS:--std=c11 -O2 -Wall -Wextra}"
ROUNDS="${ROUNDS:-7}"
mkdir -p "$OUT_DIR" "$BENCH/build"
BUILD="$BENCH/build"

if [[ ! -x "$LINT_BIN" ]]; then
  make -C "$ROOT/cperf-lint" -j"$(nproc)"
  LINT_BIN="$ROOT/cperf-lint/cperf-lint"
fi

ENV_OUT="$OUT_DIR/env.txt"
{
  echo "ts=$(date -Iseconds)"
  echo "cc=$($CC_BIN --version | head -1)"
  echo "uname=$(uname -a)"
  echo "nproc=$(nproc)"
  echo "cflags=$CFLAGS"
  echo "rounds=$ROUNDS"
} | tee "$ENV_OUT"

median() {
  # stdin: one float per line → stdout median
  sort -n | awk '
    { a[NR]=$1 }
    END {
      if (NR==0) { print "nan"; exit 1 }
      if (NR%2) print a[int(NR/2)+1]
      else print (a[NR/2]+a[NR/2+1])/2
    }'
}

run_pair() {
  local name="$1" bin_smell="$2" bin_clean="$3" n_arg="$4"
  local smell_ms clean_ms
  local samples_s=() samples_c=()
  local i t
  for ((i=0; i<ROUNDS; i++)); do
    t=$("$bin_smell" smell $n_arg)
    samples_s+=("$t")
    t=$("$bin_clean" clean $n_arg)
    samples_c+=("$t")
  done
  smell_ms=$(printf '%s\n' "${samples_s[@]}" | median)
  clean_ms=$(printf '%s\n' "${samples_c[@]}" | median)
  awk -v s="$smell_ms" -v c="$clean_ms" -v name="$name" 'BEGIN {
    ratio = (c>0 ? s/c : 0)
    printf "%s\t%.6f\t%.6f\t%.3f\n", name, s, c, ratio
  }'
}

lint_hits() {
  local f="$1"
  "$LINT_BIN" --no-fail --format text "$f" 2>/dev/null | grep -cE 'CP00[0-9]' || true
}

echo "=== build ==="
$CC_BIN $CFLAGS -o "$BUILD/case1" "$BENCH/case1_malloc_vs_arena.c"
$CC_BIN $CFLAGS -o "$BUILD/case2" "$BENCH/case2_printf_hot.c"
$CC_BIN $CFLAGS -DINCLUDE_DEAD_DUMP -o "$BUILD/case3_smell" "$BENCH/case3_dead_printf.c"
$CC_BIN $CFLAGS -o "$BUILD/case3_clean" "$BENCH/case3_dead_printf.c"
$CC_BIN $CFLAGS -o "$BUILD/case4" "$BENCH/case4_realloc_growth.c"

echo "=== lint probes ==="
LINT_SUMMARY="$OUT_DIR/lint-probes.txt"
: > "$LINT_SUMMARY"
for f in "$PROBES"/*.c; do
  hits=$(lint_hits "$f")
  rules=$("$LINT_BIN" --no-fail --format text "$f" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//')
  echo "$(basename "$f") hits=$hits rules=${rules:-none}" | tee -a "$LINT_SUMMARY"
done

echo "=== wall times (ms, median of $ROUNDS) ==="
RESULTS="$OUT_DIR/static-vs-o2.tsv"
JSONL="$OUT_DIR/static-vs-o2.jsonl"
: > "$JSONL"
{
  echo -e "case\tsmell_ms\tclean_ms\tratio"
  # case1: N=200000
  line=$(run_pair case1_malloc_vs_arena "$BUILD/case1" "$BUILD/case1" 200000)
  echo "$line"
  smell=$(echo "$line" | cut -f2); clean=$(echo "$line" | cut -f3); ratio=$(echo "$line" | cut -f4)
  printf '{"case":"1_malloc_vs_arena","smell_ms":%s,"clean_ms":%s,"ratio":%s,"n":200000}\n' "$smell" "$clean" "$ratio" >> "$JSONL"

  # case2: compare smell vs clean (buffered); also record silent separately
  line=$(run_pair case2_printf_hot "$BUILD/case2" "$BUILD/case2" 80000)
  echo "$line"
  smell=$(echo "$line" | cut -f2); clean=$(echo "$line" | cut -f3); ratio=$(echo "$line" | cut -f4)
  printf '{"case":"2_printf_hot","smell_ms":%s,"clean_ms":%s,"ratio":%s,"n":80000}\n' "$smell" "$clean" "$ratio" >> "$JSONL"

  # silent median for case2 context
  silent_samples=()
  for ((i=0; i<ROUNDS; i++)); do silent_samples+=("$("$BUILD/case2" silent 80000)"); done
  silent_ms=$(printf '%s\n' "${silent_samples[@]}" | median)
  echo -e "case2_silent\t$silent_ms\t$silent_ms\t1.000"
  printf '{"case":"2_silent_ref","ms":%s,"n":80000}\n' "$silent_ms" >> "$JSONL"

  # case3: smell binary vs clean binary (same hot path)
  samples_s=(); samples_c=()
  for ((i=0; i<ROUNDS; i++)); do
    samples_s+=("$("$BUILD/case3_smell" smell 2000000)")
    samples_c+=("$("$BUILD/case3_clean" clean 2000000)")
  done
  smell_ms=$(printf '%s\n' "${samples_s[@]}" | median)
  clean_ms=$(printf '%s\n' "${samples_c[@]}" | median)
  ratio=$(awk -v s="$smell_ms" -v c="$clean_ms" 'BEGIN{printf "%.3f", (c>0?s/c:0)}')
  echo -e "case3_dead_printf\t$smell_ms\t$clean_ms\t$ratio"
  printf '{"case":"3_dead_printf","smell_ms":%s,"clean_ms":%s,"ratio":%s,"n":2000000}\n' "$smell_ms" "$clean_ms" "$ratio" >> "$JSONL"

  # case4
  line=$(run_pair case4_realloc_growth "$BUILD/case4" "$BUILD/case4" 100000)
  echo "$line"
  smell=$(echo "$line" | cut -f2); clean=$(echo "$line" | cut -f3); ratio=$(echo "$line" | cut -f4)
  printf '{"case":"4_realloc_growth","smell_ms":%s,"clean_ms":%s,"ratio":%s,"n":100000}\n' "$smell" "$clean" "$ratio" >> "$JSONL"
} | tee "$RESULTS"

echo "TSV  -> $RESULTS"
echo "JSONL -> $JSONL"
echo "env  -> $ENV_OUT"
echo "lint -> $LINT_SUMMARY"
