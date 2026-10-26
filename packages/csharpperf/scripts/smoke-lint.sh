#!/usr/bin/env bash
set -euo pipefail
# Prefer a dotnet already on PATH. Fall back to the user-local install script layout.
if ! command -v dotnet >/dev/null 2>&1 && [[ -x "${HOME}/.dotnet/dotnet" ]]; then
  export PATH="${HOME}/.dotnet:${PATH}"
  export DOTNET_ROOT="${HOME}/.dotnet"
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v dotnet >/dev/null 2>&1; then
  echo "csharpperf-lint smoke SKIP (no dotnet SDK); fixtures present"
  ls "$ROOT/csharpperf-lint/fixtures/bad" "$ROOT/csharpperf-lint/fixtures/good" >/dev/null
  exit 0
fi
cd "$ROOT/csharpperf-lint"
dotnet build -c Release -v q
BIN=(dotnet run -c Release --no-build --)
set +e
"${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/bad" \
  --severity cs-list-add-no-capacity=error --severity cs-string-plus-in-loop=error --severity cs-console-in-loop=error --severity cs-regex-in-loop=error
b=$?
"${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/good"
g=$?
"${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/bad/cs-regex-in-loop_regex_loop.cs"
h=$?
"${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/bad/cs-regex-in-loop_regex_loop.cs" --strict-hints
s=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "cs-regex-in-loop hint should exit 0, got $h"; exit 1; }
[[ "$s" -eq 1 ]] || { echo "cs-regex-in-loop strict-hints should exit 1, got $s"; exit 1; }
check_pair() {
  local rule="$1" badf="$2" goodf="$3"
  set +e
  "${BIN[@]}" "$badf" --severity "${rule}=error"
  local be=$?
  "${BIN[@]}" "$goodf" --strict-hints
  local ge=$?
  set -e
  [[ "$be" -eq 1 ]] || { echo "$rule bad should exit 1, got $be"; exit 1; }
  [[ "$ge" -eq 0 ]] || { echo "$rule good should exit 0, got $ge"; exit 1; }
}
check_pair cs-linq-materialize-in-loop "$ROOT/csharpperf-lint/fixtures/bad/cs-linq-materialize-in-loop_tolist_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-linq-materialize-in-loop_tolist_once.cs"
check_pair cs-format-in-loop "$ROOT/csharpperf-lint/fixtures/bad/cs-format-in-loop_format_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-format-in-loop_format_once.cs"
check_pair cs-json-in-loop "$ROOT/csharpperf-lint/fixtures/bad/cs-json-in-loop_json_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-json-in-loop_json_once.cs"
json_n=$("${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/bad/cs-json-in-loop_json_loop.cs" --severity cs-json-in-loop=error --no-fail | grep -c 'cs-json-in-loop' || true)
[[ "$json_n" -eq 4 ]] || { echo "cs-json-in-loop expected 4 findings, got ${json_n}"; exit 1; }
check_pair cs-file-read-in-loop "$ROOT/csharpperf-lint/fixtures/bad/cs-file-read-in-loop_read_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-file-read-in-loop_read_once.cs"
check_pair cs-clock-in-loop "$ROOT/csharpperf-lint/fixtures/bad/cs-clock-in-loop_clock_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-clock-in-loop_clock_once.cs"
check_pair cs-field-by-name-in-loop "$ROOT/csharpperf-lint/fixtures/bad/cs-field-by-name-in-loop_field_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-field-by-name-in-loop_field_once.cs"
check_pair cs-regex-in-loop "$ROOT/csharpperf-lint/fixtures/bad/cs-regex-in-loop_new_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-regex-in-loop_new_once.cs"
echo "csharpperf-lint smoke ok"
