#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# G1: lint own non-bench examples (bench/*.exs deliberately contain smells).
elixir "$ROOT/beamperf-lint/beamperf_lint.exs" \
  "$ROOT/examples/m01_cons.exs" \
  "$ROOT/examples/m01_cons.erl" \
  "$ROOT/examples/p01_iodata.exs" \
  --scope loop --strict-hints
echo "beamperf-lint self-lint ok"
