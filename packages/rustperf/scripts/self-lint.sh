#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/rustperf-lint"
cargo build -q --release
# Examples are the dogfood surface for scaffold (checker source mentions smell tokens).
./target/release/rustperf-lint ../examples --strict-hints
echo "rustperf-lint self-lint ok"
