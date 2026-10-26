#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node "$ROOT/arktsperf-lint/bin/arktsperf-lint.js" \
  "$ROOT/arktsperf-lint/bin" "$ROOT/arktsperf-lint/lib" --strict-hints
echo "arktsperf-lint self-lint ok"
