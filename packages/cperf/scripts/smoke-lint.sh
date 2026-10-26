#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/cperf-lint"
make -s all
make -s smoke
make -s self-lint
BIN="$ROOT/cperf-lint/cperf-lint"

# Each new slug needs its own pair. The whole bad/ tree already exits 1
# because older error rules fire there.
check_pair() {
  local rule="$1" badf="$2" goodf="$3" min="$4"
  local out gout
  local be hd ae ge
  set +e
  out=$("$BIN" "$badf" --severity "${rule}=error" --format text 2>&1)
  be=$?
  "$BIN" "$badf" --format text >/dev/null 2>&1
  hd=$?
  "$BIN" "$badf" --preset all --format text >/dev/null 2>&1
  ae=$?
  gout=$("$BIN" "$goodf" --strict-hints --format text 2>&1)
  ge=$?
  set -e
  if [[ "$be" -ne 1 ]]; then
    echo "$rule bad with ${rule}=error should exit 1, got $be"
    printf '%s\n' "$out"
    exit 1
  fi
  if [[ "$hd" -ne 0 ]]; then
    echo "$rule default hint should exit 0, got $hd"
    exit 1
  fi
  if [[ "$ae" -ne 1 ]]; then
    echo "$rule preset all should exit 1, got $ae"
    exit 1
  fi
  if [[ "$ge" -ne 0 ]]; then
    echo "$rule good with --strict-hints should exit 0, got $ge"
    printf '%s\n' "$gout"
    exit 1
  fi
  if printf '%s\n' "$gout" | grep -q 'cp-'; then
    echo "$rule good emitted a finding"
    printf '%s\n' "$gout"
    exit 1
  fi
  local n
  n=$(printf '%s\n' "$out" | grep -c "$rule" || true)
  if [[ "$n" -lt "$min" ]]; then
    echo "$rule expected at least $min hits, got $n"
    printf '%s\n' "$out"
    exit 1
  fi
  local extra
  extra=$(printf '%s\n' "$out" | grep -oE 'cp-[a-z0-9-]+' | grep -v -x "$rule" || true)
  if [[ -n "$extra" ]]; then
    echo "$rule bad fired another rule:"
    printf '%s\n' "$extra"
    exit 1
  fi
}

check_pair cp-sprintf-in-loop \
  "$ROOT/cperf-lint/fixtures/bad/cp-sprintf-in-loop_sprintf_loop.c" \
  "$ROOT/cperf-lint/fixtures/good/cp-sprintf-in-loop_sprintf_once.c" \
  2
check_pair cp-fopen-in-loop \
  "$ROOT/cperf-lint/fixtures/bad/cp-fopen-in-loop_fopen_loop.c" \
  "$ROOT/cperf-lint/fixtures/good/cp-fopen-in-loop_fopen_once.c" \
  1
check_pair cp-gettime-in-loop \
  "$ROOT/cperf-lint/fixtures/bad/cp-gettime-in-loop_gettime_loop.c" \
  "$ROOT/cperf-lint/fixtures/good/cp-gettime-in-loop_time_in_loop.c" \
  2
check_pair cp-wide-bool-flags \
  "$ROOT/cperf-lint/fixtures/bad/cp-wide-bool-flags_ints.c" \
  "$ROOT/cperf-lint/fixtures/good/cp-wide-bool-flags_bits.c" \
  1
check_pair cp-regex-in-loop \
  "$ROOT/cperf-lint/fixtures/bad/cp-regex-in-loop_regcomp_loop.c" \
  "$ROOT/cperf-lint/fixtures/good/cp-regex-in-loop_regcomp_once.c" \
  1
check_pair cp-alloca-in-loop \
  "$ROOT/cperf-lint/fixtures/bad/cp-alloca-in-loop_alloca_loop.c" \
  "$ROOT/cperf-lint/fixtures/good/cp-alloca-in-loop_alloca_once.c" \
  2
check_pair cp-struct-by-value \
  "$ROOT/cperf-lint/fixtures/bad/cp-struct-by-value_blob.c" \
  "$ROOT/cperf-lint/fixtures/good/cp-struct-by-value_pointer.c" \
  1
echo "cperf-lint smoke ok"
