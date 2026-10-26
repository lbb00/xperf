#!/usr/bin/env bash
# Mechanical checks for tracked Markdown. Standard: docs/doc-style.md.
#   bash scripts/doc-check.sh [pathspec...]   (default: all tracked *.md)
# The guide-vs-guide-src check is separate: scripts/build-guides.sh --check.
set -euo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ $# -gt 0 ]]; then
  FILES="$(git ls-files -co --exclude-standard -- "$@" | grep -E '\.md$' || true)"
else
  FILES="$(git ls-files -co --exclude-standard '*.md' ':(exclude).claude')"
fi

FAIL=0
err() { echo "doc-check: $1" >&2; FAIL=1; }

# Fence-aware per-file checks; emits ERR/LINK records.
scan() { # file shard(0|1): shards are fragments of a generated guide
  awk -v shard="$2" '
    BEGIN { fence = 0; first = 1; h1 = 0; prev = 0; lastnl = 1 }
    {
      line = $0
      if (FNR == 1 && line == "---") { fm = 1; first = 0; next }
      if (fm) { if (line == "---") fm = 0; next }
      if (line ~ /^[ ]{0,3}(```|~~~)/) { fence = !fence; next }
      if (fence) next
      if (line ~ /[ \t]+$/) print "ERR\t" FILENAME ":" FNR ": trailing whitespace"
      if (line ~ /\r$/) print "ERR\t" FILENAME ":" FNR ": CRLF line ending"
      if (first && line ~ /^[ \t]*$/) next
      if (first && !shard) {
        first = 0
        if (line !~ /^# /) print "ERR\t" FILENAME ":" FNR ": first line must be an H1"
      }
      if (!shard && match(line, /^#+ /)) {
        lvl = RLENGTH - 1
        if (lvl == 1) { h1++; if (h1 > 1) print "ERR\t" FILENAME ":" FNR ": more than one H1" }
        if (prev && lvl > prev + 1) print "ERR\t" FILENAME ":" FNR ": heading level skips (h" prev " -> h" lvl ")"
        prev = lvl
      }
      s = line
      while (match(s, /\]\([^)]+\)/)) {
        print "LINK\t" FILENAME "\t" FNR "\t" substr(s, RSTART + 2, RLENGTH - 3)
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # exactly one trailing newline
  shard=0; base="$(dirname "$f")"
  if [[ "$f" == */guide-src/* ]]; then shard=1; base="${base/\/guide-src/}"; fi
  if [[ -s "$f" ]]; then
    last="$(tail -c1 "$f" | od -An -c | tr -d ' ')"
    prev2="$(tail -c2 "$f" | od -An -c | tr -d ' ')"
    [[ "$last" == '\n' ]] || err "$f: missing final newline"
    [[ "$shard" == 0 && "$prev2" == '\n\n' ]] && err "$f: more than one trailing newline"
  fi
  while IFS=$'\t' read -r kind a b c; do
    case "$kind" in
      ERR) err "$a" ;;
      LINK)
        t="${c%% *}"; t="${t#<}"; t="${t%>}"
        [[ -z "$t" || "$t" =~ ^[A-Za-z][A-Za-z0-9+.-]*: || "$t" == \#* ]] && continue
        t="${t%%#*}"; t="${t%%\?*}"
        [[ -z "$t" ]] && continue
        [[ -e "$base/$t" ]] || err "$a:$b: broken link -> $t"
        ;;
    esac
  done < <(scan "$f" "$shard")
done <<< "$FILES"

# Kits are not released on their own: no per-kit version in package docs.
KITVER='(^|[^0-9.])0\.(1\.[0-9]|3\.[0-9]|4\.[0-9])([^0-9]|$)'
while IFS= read -r f; do
  [[ -z "$f" || "$f" != packages/* || "$f" == */CHANGELOG.md ]] && continue
  while IFS= read -r hit; do
    err "$f:${hit%%:*}: per-kit version (kits have none; releases are repo-wide git tags)"
  done < <(grep -nE "$KITVER" "$f" || true)
done <<< "$FILES"

# Required headings per file kind.
need() { # file heading...
  local f="$1"; shift
  [[ -f "$f" ]] || return 0
  if [[ $# -gt 0 ]]; then
    for h in "$@"; do
      grep -qxF "$h" "$f" || err "$f: missing heading '$h'"
    done
  fi
}
for kit in packages/*/; do
  k="${kit%/}"
  if [[ $# -gt 0 && -z "$(git ls-files -co --exclude-standard -- "$@" | grep "^$k/" || true)" ]]; then continue; fi
  need "$k/README.md" "## Run lint" "## Layout"
  need "$k/docs/evidence-policy.md" "## Gate" "## Current map"
  need "$k/docs/corpus.md" "## Pins"
done

if [[ "$FAIL" == 1 ]]; then
  echo "doc-check: FAILED" >&2
  exit 1
fi
echo "doc-check: OK"
