#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v kotlinc >/dev/null 2>&1; then
  echo "kotlinperf-lint self-lint SKIP (no kotlinc)"
  exit 0
fi
bash "$ROOT/kotlinperf-lint/build.sh"
"$ROOT/kotlinperf-lint/kotlinperf-lint" "$ROOT/kotlinperf-lint/src" --scope loop --strict-hints
echo "kotlinperf-lint self-lint ok"
