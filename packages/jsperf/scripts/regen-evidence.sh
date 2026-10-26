#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node "$ROOT/examples/bench/evidence_jp003_jp004.js"
node "$ROOT/examples/bench/evidence_jp001_jp002.js"
node "$ROOT/examples/bench/evidence_jp005_jp006.js"
echo "wrote evidence jsonl"
