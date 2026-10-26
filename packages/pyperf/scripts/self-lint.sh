#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$ROOT/pyperf-lint${PYTHONPATH:+:$PYTHONPATH}"
python3 -m pyperf_lint "$ROOT/pyperf-lint/pyperf_lint" --strict-hints
echo "pyperf-lint self-lint ok"
