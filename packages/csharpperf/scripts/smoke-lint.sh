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
  --severity cs-list-add-no-capacity=error --severity cs-string-plus-hot=error --severity cs-console-hot=error --severity cs-regex-hot=error
b=$?
"${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/good"
g=$?
"${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/bad/cs-regex-hot_regex_loop.cs"
h=$?
"${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/bad/cs-regex-hot_regex_loop.cs" --strict-hints
s=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "cs-regex-hot hint should exit 0, got $h"; exit 1; }
[[ "$s" -eq 1 ]] || { echo "cs-regex-hot strict-hints should exit 1, got $s"; exit 1; }
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
check_pair cs-linq-materialize-hot "$ROOT/csharpperf-lint/fixtures/bad/cs-linq-materialize-hot_tolist_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-linq-materialize-hot_quiet.cs"
check_pair cs-format-hot "$ROOT/csharpperf-lint/fixtures/bad/cs-format-hot_format_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-format-hot_quiet.cs"
check_pair cs-json-hot "$ROOT/csharpperf-lint/fixtures/bad/cs-json-hot_json_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-json-hot_text_varies.cs"
json_n=$("${BIN[@]}" "$ROOT/csharpperf-lint/fixtures/bad/cs-json-hot_json_loop.cs" --severity cs-json-hot=error --no-fail | grep -c 'cs-json-hot' || true)
[[ "$json_n" -eq 4 ]] || { echo "cs-json-hot expected 4 findings, got ${json_n}"; exit 1; }
check_pair cs-file-read-hot "$ROOT/csharpperf-lint/fixtures/bad/cs-file-read-hot_read_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-file-read-hot_path_varies.cs"
check_pair cs-clock-hot "$ROOT/csharpperf-lint/fixtures/bad/cs-clock-hot_clock_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-clock-hot_await_loop.cs"
check_pair cs-field-by-name-hot "$ROOT/csharpperf-lint/fixtures/bad/cs-field-by-name-hot_field_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-field-by-name-hot_field_once.cs"
check_pair cs-regex-hot "$ROOT/csharpperf-lint/fixtures/bad/cs-regex-hot_new_loop.cs" "$ROOT/csharpperf-lint/fixtures/good/cs-regex-hot_pattern_varies.cs"
echo "csharpperf-lint smoke ok"
