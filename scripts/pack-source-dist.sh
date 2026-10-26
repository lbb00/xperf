#!/usr/bin/env bash
# Build XPerf source distribution (packages + docs, no corpora / build caches).
# Usage: scripts/pack-source-dist.sh <tag> [outdir]
set -euo pipefail

TAG="${1:?tag required, e.g. v0.1.0}"
OUTDIR="${2:-dist}"
ASSET="xperf-${TAG}-packages.tar.gz"
ROOT_NAME="xperf-${TAG}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$(mktemp -d)"
trap 'rm -rf "${STAGING}"' EXIT
ROOT="${STAGING}/${ROOT_NAME}"
mkdir -p "${ROOT}"

cd "${REPO_ROOT}"

for f in README.md LICENSE NOTICE AGENT.md CONTRIBUTING.md CHANGELOG.md \
         CODE_OF_CONDUCT.md SECURITY.md mkdocs.yml; do
  if [[ -f "$f" ]]; then
    cp -a "$f" "${ROOT}/"
  fi
done

cp -a docs "${ROOT}/docs"
cp -a pages "${ROOT}/pages"
cp -a scripts "${ROOT}/scripts"
cp -a packages "${ROOT}/packages"
if [[ -d site-app ]]; then
  cp -a site-app "${ROOT}/site-app"
  rm -rf "${ROOT}/site-app/node_modules" "${ROOT}/site-app/.next" \
    "${ROOT}/site-app/out" "${ROOT}/site-app/.source" \
    "${ROOT}/site-app/content" "${ROOT}/site-app/public"
fi

# Remove caches and local build outputs (keep source + fixtures + evidence docs)
while IFS= read -r -d '' d; do
  rm -rf "$d"
done < <(find "${ROOT}" -type d \( \
  -name .zig-cache -o -name zig-out -o -name node_modules -o \
  -name target -o -name .gradle -o -name build -o -name dist -o \
  -name __pycache__ -o -name .git -o -name .dart_tool -o -name vendor -o \
  -name obj -o -name site -o -name site-src -o -name .venv -o -name .claude \
\) -print0)

while IFS= read -r -d '' d; do
  rm -rf "$d"
done < <(find "${ROOT}" -type d \( -path '*/bin/Release' -o -path '*/bin/Debug' \) -print0)

find "${ROOT}" -type f \( \
  -name '*.o' -o -name '*.pyc' -o -name '*.class' -o -name '*.bin' -o \
  -name '*.exe' -o -name '*.pdb' -o -name '*.dll' -o -name '.DS_Store' \
\) -delete

# Drop compiled lint binaries (keep gradlew / shell helpers)
find "${ROOT}/packages" -type f -perm -111 \
  ! -name '*.sh' ! -name '*.py' ! -name '*.bash' \
  ! -name 'gradlew' ! -name 'gradlew.bat' \
  ! -path '*/scripts/*' \
  -delete 2>/dev/null || true

mkdir -p "${OUTDIR}"
OUT_ABS="$(cd "${OUTDIR}" && pwd)"
tar -C "${STAGING}" -czf "${OUT_ABS}/${ASSET}" "${ROOT_NAME}"
(cd "${OUT_ABS}" && sha256sum "${ASSET}" > "${ASSET}.sha256")

echo "Wrote ${OUT_ABS}/${ASSET}"
echo "Wrote ${OUT_ABS}/${ASSET}.sha256"
cat "${OUT_ABS}/${ASSET}.sha256"
