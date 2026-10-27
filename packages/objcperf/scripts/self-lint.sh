#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/objcperf-lint"
make -s
# Checker sources are C. Copy them to .m so this ObjC scanner can see self-hits.
# Old rules stay off: the append token already lives in the scan loop.
workdir="$(mktemp -d "${TMPDIR:-/tmp}/objcperf-self.XXXXXX")"
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT
cp src/scan.c "$workdir/scan.m"
cp src/main.c "$workdir/main.m"
cp src/objcperf_lint.h "$workdir/objcperf_lint.h"
./objcperf-lint "$workdir" ../examples src --scope loop --strict-hints
echo "objcperf-lint self-lint ok"
