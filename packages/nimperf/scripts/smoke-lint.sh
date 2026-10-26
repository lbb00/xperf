#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/.nimble/bin:${PATH}"
if ! command -v nim >/dev/null 2>&1; then
  echo "smoke: nim toolchain missing — skip (install choosenim); see docs/corpus.md"
  exit 0
fi
BIN=("$ROOT/nimperf-lint/nimperf-lint")
set +e
"${BIN[@]}" "$ROOT/nimperf-lint/fixtures/bad" \
  --severity nm-seq-add-in-loop=error --severity nm-echo-in-loop=error --severity nm-seq-no-capacity=error
b=$?
"${BIN[@]}" "$ROOT/nimperf-lint/fixtures/good"
g=$?
"${BIN[@]}" "$ROOT/nimperf-lint/fixtures/bad/nm-seq-no-capacity_empty_add.nim"
h=$?
set -e
[[ "$b" -eq 1 ]] || { echo "bad should exit 1, got $b"; exit 1; }
[[ "$g" -eq 0 ]] || { echo "good should exit 0, got $g"; exit 1; }
[[ "$h" -eq 0 ]] || { echo "hint should exit 0, got $h"; exit 1; }
out=$("${BIN[@]}" "$ROOT/nimperf-lint/fixtures/bad" --format json --no-fail)
echo "$out" | grep -q '"nm-seq-no-capacity"' || { echo "default should report nm-seq-no-capacity"; exit 1; }
echo "nimperf-lint smoke ok"
