#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/cppperf-lint"
make -s
BIN="$ROOT/cppperf-lint/cppperf-lint"
set +e
"$BIN" "$ROOT/cppperf-lint/fixtures/bad" --severity cx-regex-ctor-hot=error
b=$?
"$BIN" "$ROOT/cppperf-lint/fixtures/good"
g=$?
# default is hint → exit 0; strict-hints → 1
"$BIN" "$ROOT/cppperf-lint/fixtures/bad"
h=$?
"$BIN" "$ROOT/cppperf-lint/fixtures/bad" --strict-hints
s=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad error should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "default hint should exit 0, got $h"; exit 1; }
[[ "$s" -eq 1 ]] || { echo "strict-hints should exit 1, got $s"; exit 1; }
check_pair() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  "$BIN" "$badf" --severity "${rule}=error"
  local be=$?
  "$BIN" "$goodf" --strict-hints
  local ge=$?
  set -e
  [[ "$be" -eq 1 ]] || { echo "$rule bad should exit 1, got $be"; exit 1; }
  [[ "$ge" -eq 0 ]] || { echo "$rule good should exit 0, got $ge"; exit 1; }
}
check_pair cx-regex-ctor-hot "$ROOT/cppperf-lint/fixtures/bad/cx-regex-ctor-hot_regex_loop.cpp" "$ROOT/cppperf-lint/fixtures/good/cx-regex-ctor-hot_pattern_varies.cpp"
check_pair cx-endl-hot "$ROOT/cppperf-lint/fixtures/bad/cx-endl-hot_endl_loop.cpp" "$ROOT/cppperf-lint/fixtures/good/cx-endl-hot_newline.cpp"
check_pair cx-clock-hot "$ROOT/cppperf-lint/fixtures/bad/cx-clock-hot_clock_loop.cpp" "$ROOT/cppperf-lint/fixtures/good/cx-clock-hot_quiet.cpp"
check_pair cx-ifstream-hot "$ROOT/cppperf-lint/fixtures/bad/cx-ifstream-hot_open_loop.cpp" "$ROOT/cppperf-lint/fixtures/good/cx-ifstream-hot_path_varies.cpp"
check_pair cx-const-by-value "$ROOT/cppperf-lint/fixtures/bad/cx-const-by-value_copy.cpp" "$ROOT/cppperf-lint/fixtures/good/cx-const-by-value_ref.cpp"
check_pair cx-vector-bool "$ROOT/cppperf-lint/fixtures/bad/cx-vector-bool_packed.cpp" "$ROOT/cppperf-lint/fixtures/good/cx-vector-bool_byte.cpp"
clock_out=$("$BIN" "$ROOT/cppperf-lint/fixtures/bad/cx-clock-hot_clock_loop.cpp" --severity cx-clock-hot=error --format text 2>&1 || true)
clock_n=$(printf '%s\n' "$clock_out" | grep -c 'cx-clock-hot' || true)
if [[ "$clock_n" -lt 5 ]]; then
  echo "cx-clock-hot expected at least 5 hits, got $clock_n"
  printf '%s\n' "$clock_out"
  exit 1
fi
clock_extra=$(printf '%s\n' "$clock_out" | grep -oE 'cx-[a-z0-9-]+' | grep -v -x 'cx-clock-hot' || true)
if [[ -n "$clock_extra" ]]; then
  echo "cx-clock-hot bad fired another rule:"
  printf '%s\n' "$clock_extra"
  exit 1
fi
const_out=$("$BIN" "$ROOT/cppperf-lint/fixtures/bad/cx-const-by-value_copy.cpp" --severity cx-const-by-value=error --format text 2>&1 || true)
const_n=$(printf '%s\n' "$const_out" | grep -c 'cx-const-by-value' || true)
if [[ "$const_n" -ne 6 ]]; then
  echo "cx-const-by-value expected 6 hits, got $const_n"
  printf '%s\n' "$const_out"
  exit 1
fi
const_extra=$(printf '%s\n' "$const_out" | grep -oE 'cx-[a-z0-9-]+' | grep -v -x 'cx-const-by-value' || true)
if [[ -n "$const_extra" ]]; then
  echo "cx-const-by-value bad fired another rule:"
  printf '%s\n' "$const_extra"
  exit 1
fi
vbool_out=$("$BIN" "$ROOT/cppperf-lint/fixtures/bad/cx-vector-bool_packed.cpp" --severity cx-vector-bool=error --format text 2>&1 || true)
vbool_n=$(printf '%s\n' "$vbool_out" | grep -c 'cx-vector-bool' || true)
if [[ "$vbool_n" -ne 1 ]]; then
  echo "cx-vector-bool expected 1 hit, got $vbool_n"
  printf '%s\n' "$vbool_out"
  exit 1
fi
vbool_extra=$(printf '%s\n' "$vbool_out" | grep -oE 'cx-[a-z0-9-]+' | grep -v -x 'cx-vector-bool' || true)
if [[ -n "$vbool_extra" ]]; then
  echo "cx-vector-bool bad fired another rule:"
  printf '%s\n' "$vbool_extra"
  exit 1
fi
echo "cppperf-lint smoke ok"
