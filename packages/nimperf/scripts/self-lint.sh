#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/.nimble/bin:${PATH}"
if ! command -v nim >/dev/null 2>&1; then
  echo "self-lint: nim toolchain missing — skip"
  exit 0
fi
"$ROOT/nimperf-lint/nimperf-lint" "$ROOT/nimperf-lint/nimperf_lint.nim" --scope loop --strict-hints
echo "nimperf-lint self-lint ok"
