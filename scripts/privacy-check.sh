#!/usr/bin/env bash
# Fail if tracked files (or, with --history, any past revision / commit message)
# contain private network addresses, local absolute paths, or credentials.
#
# Names that must not appear (company/product/host names) are NOT listed here:
# listing them in a public repo would itself leak them. Put one case-insensitive
# fixed string per line in $XPERF_PRIVACY_DENYLIST, or in
# ~/.config/xperf/privacy-denylist; they are checked when the file exists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HISTORY=0
[[ "${1:-}" == "--history" ]] && HISTORY=1

SELF=':(exclude)scripts/privacy-check.sh'
DENYLIST="${XPERF_PRIVACY_DENYLIST:-$HOME/.config/xperf/privacy-denylist}"

# Structural patterns (ERE, no \b: BSD/macOS regex lacks it). 100.64.0.0/10 is the CGNAT range Tailscale uses.
PATTERNS=(
  '\.ts\.net'
  'tailscale'
  '(^|[^0-9.])100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}'
  '(^|[^0-9.])10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
  '(^|[^0-9.])192\.168\.[0-9]{1,3}\.[0-9]{1,3}'
  '(^|[^0-9.])172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}'
  '/Users/[A-Za-z0-9._-]+/'
  '/Volumes/[A-Za-z0-9._ -]+/'
  '/home/[a-z_][a-z0-9_-]*/'
  'C:\\Users\\'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  '(ghp|gho|ghs|github_pat)_[A-Za-z0-9_]{20,}'
  'AKIA[0-9A-Z]{16}'
)

# Maintainer-machine layout leaks. Checked on the working tree only: past
# revisions are public history and cannot be changed by this check.
LAYOUT_PATTERNS=(
  'XPERF_RESEARCH'
  'xperf-research'
  '/workspace/'
  '(this|the) box([^a-z]|$)'
  'box-local'
  'box only'
  'box (clock|clones)'
  'box (ratio|note)'
  'box without'
  'Mac sync'
  'teammate'
)

FAIL=0
report() { # label, matches
  if [[ -n "$2" ]]; then
    echo "privacy-check: $1" >&2
    echo "$2" >&2
    FAIL=1
  fi
}

scan_tree() { # rev ("" = working tree of tracked files)
  local rev="$1" label="${1:-working tree}" out p
  local pats=("${PATTERNS[@]}")
  [[ -z "$rev" ]] && pats+=("${LAYOUT_PATTERNS[@]}")
  for p in "${pats[@]}"; do
    out="$(git grep -n -I -i -E -e "$p" $rev -- . "$SELF" 2>/dev/null || true)"
    report "$label matches /$p/" "$out"
  done
  if [[ -f "$DENYLIST" ]]; then
    while IFS= read -r word; do
      [[ -z "$word" || "$word" == \#* ]] && continue
      out="$(git grep -n -I -i -F -e "$word" $rev -- . "$SELF" 2>/dev/null || true)"
      report "$label matches denylist entry (see $DENYLIST)" "$out"
    done < "$DENYLIST"
  fi
}

scan_tree ""

if [[ "$HISTORY" == 1 ]]; then
  for rev in $(git rev-list --all); do
    scan_tree "$rev"
  done
  msgs="$(git log --all --format='%H %an <%ae> %cn <%ce>%n%B')"
  for p in "${PATTERNS[@]}"; do
    out="$(printf '%s\n' "$msgs" | grep -n -i -E -e "$p" || true)"
    report "commit metadata matches /$p/" "$out"
  done
  if [[ -f "$DENYLIST" ]]; then
    while IFS= read -r word; do
      [[ -z "$word" || "$word" == \#* ]] && continue
      out="$(printf '%s\n' "$msgs" | grep -n -i -F -e "$word" || true)"
      report "commit metadata matches denylist entry" "$out"
    done < "$DENYLIST"
  fi
fi

if [[ "$FAIL" == 1 ]]; then
  echo "privacy-check: FAILED" >&2
  exit 1
fi
[[ -f "$DENYLIST" ]] || echo "privacy-check: note — no local denylist at $DENYLIST (structural patterns only)"
echo "privacy-check: OK"
