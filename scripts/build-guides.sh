#!/usr/bin/env bash
# Rebuild each kit's performance guide from docs/guide-src/ (the source of truth).
#   bash scripts/build-guides.sh [kit...]           write the guides (default: all kits)
#   bash scripts/build-guides.sh --check [kit...]   exit 1 if a committed guide differs
# Layouts: docs/guide-src/*.md -> docs/*-performance-guide.md
#          docs/guide-src/<lang>/*.md -> docs/<lang>/<matching-stem>.md
# For locale pairing, zh-CN output reuses the English *-performance-guide.md basename
# when present; otherwise performance-guide.md (jvmperf-style en/zh-CN layout).
set -euo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE=build
if [[ "${1:-}" == "--check" ]]; then MODE=check; shift; fi
KITS=("$@")
FAIL=0

build() { # shard_dir out
  local dir="$1" out="$2"
  local shards=("$dir"/*.md)
  [[ -e "${shards[0]}" ]] || return 0
  mkdir -p "$(dirname "$out")"
  if [[ "$MODE" == check ]]; then
    if ! cat "${shards[@]}" | cmp -s - "$out"; then
      echo "build-guides: ${out#"$ROOT"/} differs from ${dir#"$ROOT"/}/*.md" >&2
      FAIL=1
    fi
  else
    cat "${shards[@]}" > "$out"
  fi
}

lang_out() { # docs_dir lang -> stdout path
  local d="$1" lang="$2"
  local eng=("$d"/*-performance-guide.md)
  if [[ "$lang" == zh-CN && -e "${eng[0]}" ]]; then
    echo "$d/$lang/$(basename "${eng[0]}")"
  else
    echo "$d/$lang/performance-guide.md"
  fi
}

for kit in "$ROOT"/packages/*/; do
  name="$(basename "$kit")"
  if [[ ${#KITS[@]} -gt 0 ]] && [[ " ${KITS[*]} " != *" $name "* ]]; then continue; fi
  d="${kit}docs"
  [[ -d "$d/guide-src" ]] || continue
  outs=("$d"/*-performance-guide.md)
  [[ -e "${outs[0]}" ]] && build "$d/guide-src" "${outs[0]}"
  for lang in en zh-CN; do
    [[ -d "$d/guide-src/$lang" ]] || continue
    build "$d/guide-src/$lang" "$(lang_out "$d" "$lang")"
  done
done

if [[ "$FAIL" == 1 ]]; then
  echo "build-guides: FAILED (edit docs/guide-src, then run scripts/build-guides.sh)" >&2
  exit 1
fi
echo "build-guides: OK ($MODE)"
