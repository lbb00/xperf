#!/usr/bin/env bash
# List package dirs and whether lint entrypoints exist.
# Exit 1 if any *core* package is missing or lacks its lint entrypoint.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "xperf root: $ROOT"
echo

printf '%-12s %-10s %s\n' "PACKAGE" "STATUS" "LINT"
printf '%-12s %-10s %s\n' "-------" "------" "----"

FAIL=0

check_pkg() {
  local name="$1"
  local required="${2:-1}"
  local dir="$ROOT/packages/$name"
  local status="missing"
  local lint="—"
  local ok_lint=0

  if [[ ! -d "$dir" ]]; then
    printf '%-12s %-10s %s\n' "$name" "$status" "$lint"
    [[ "$required" == "1" ]] && FAIL=1
    return
  fi
  if [[ -f "$dir/README.md" ]] || [[ -f "$dir/LICENSE" ]]; then
    status="present"
  fi

  case "$name" in
    zperf)
      if [[ -f "$dir/zperf-lint/build.zig" ]]; then
        lint="zperf-lint/build.zig"; ok_lint=1
        [[ -x "$dir/zperf-lint/zig-out/bin/zperf-lint" ]] && lint="$lint (built)"
      fi
      ;;
    cperf)
      if [[ -f "$dir/cperf-lint/Makefile" ]] || [[ -f "$dir/cperf-lint/src/main.c" ]]; then
        lint="cperf-lint (C11 make)"; ok_lint=1
        [[ -x "$dir/cperf-lint/cperf-lint" ]] && lint="$lint (built)"
      fi
      ;;
    jsperf)
      if [[ -f "$dir/jsperf-lint/bin/jsperf-lint.js" ]]; then
        lint="jsperf-lint/bin/jsperf-lint.js"; ok_lint=1
      elif [[ -f "$dir/package.json" ]]; then
        lint="package.json bin"; ok_lint=1
      fi
      ;;
    jvmperf)
      if [[ -f "$dir/jvmperf-lint/bin/jvmperf-lint" ]] || [[ -f "$dir/jvmperf-lint/build.gradle.kts" ]]; then
        lint="jvmperf-lint (Gradle Java)"; ok_lint=1
        if [[ -f "$dir/jvmperf-lint/src/main/java/com/jvmperf/lint/Version.java" ]]; then
          ver=$(grep -oE 'VERSION = "[^"]+"' "$dir/jvmperf-lint/src/main/java/com/jvmperf/lint/Version.java" | head -1 | cut -d'"' -f2 || true)
          [[ -n "${ver:-}" ]] && lint="$lint $ver"
        fi
      else
        lint="stub"; status="stub"
      fi
      ;;
    goperf)
      if [[ -f "$dir/goperf-lint/cmd/goperf-lint/main.go" ]] || [[ -f "$dir/goperf-lint/go.mod" ]]; then
        lint="goperf-lint (Go)"; ok_lint=1
        [[ -x "$dir/goperf-lint/goperf-lint" ]] && lint="$lint (built)"
      else
        lint="scaffold"
      fi
      ;;
    pyperf)
      if [[ -f "$dir/pyperf-lint/pyperf_lint/__main__.py" ]] || [[ -d "$dir/pyperf-lint" ]]; then
        lint="pyperf-lint (pure Python)"; ok_lint=1
      else
        lint="scaffold"
      fi
      ;;
    swiftperf)
      if [[ -f "$dir/swiftperf-lint/Package.swift" ]] || [[ -d "$dir/swiftperf-lint" ]]; then
        lint="swiftperf-lint (Swift PM)"; ok_lint=1
        if ! command -v swift >/dev/null 2>&1; then
          lint="$lint (needs Swift toolchain)"
        fi
      else
        lint="scaffold"
      fi
      ;;
    arktsperf)
      if [[ -f "$dir/arktsperf-lint/bin/arktsperf-lint.js" ]] || [[ -d "$dir/arktsperf-lint" ]]; then
        lint="arktsperf-lint"; ok_lint=1
      else
        lint="scaffold"
      fi
      ;;
    cppperf)
      if [[ -f "$dir/cppperf-lint/Makefile" ]] || [[ -f "$dir/cppperf-lint/src/main.cpp" ]]; then
        lint="cppperf-lint (C++17 make)"; ok_lint=1
        [[ -x "$dir/cppperf-lint/cppperf-lint" ]] && lint="$lint (built)"
      else
        lint="scaffold"
      fi
      ;;
    csharpperf)
      if [[ -f "$dir/csharpperf-lint/csharpperf-lint.csproj" ]] || [[ -d "$dir/csharpperf-lint" ]]; then
        lint="csharpperf-lint (dotnet)"; ok_lint=1
        if command -v dotnet >/dev/null 2>&1 || [[ -x "${HOME}/.dotnet/dotnet" ]]; then
          lint="$lint (SDK ok)"
        else
          lint="$lint (needs dotnet SDK)"
        fi
      else
        lint="scaffold"
      fi
      ;;
    phpperf)
      if [[ -f "$dir/phpperf-lint/phpperf-lint.php" ]] || [[ -d "$dir/phpperf-lint" ]]; then
        lint="phpperf-lint (pure PHP)"; ok_lint=1
      else
        lint="scaffold"
      fi
      ;;
    rubyperf)
      if [[ -f "$dir/rubyperf-lint/rubyperf-lint.rb" ]] || [[ -d "$dir/rubyperf-lint" ]]; then
        lint="rubyperf-lint (pure Ruby)"; ok_lint=1
      else
        lint="scaffold"
      fi
      ;;
    rustperf)
      if [[ -f "$dir/rustperf-lint/Cargo.toml" ]] || [[ -d "$dir/rustperf-lint" ]]; then
        lint="rustperf-lint (Rust cargo)"; ok_lint=1
        [[ -x "$dir/rustperf-lint/target/release/rustperf-lint" ]] && lint="$lint (built)"
      else
        lint="scaffold"
      fi
      ;;
    kotlinperf)
      if [[ -f "$dir/kotlinperf-lint/src/Main.kt" ]] || [[ -d "$dir/kotlinperf-lint" ]]; then
        lint="kotlinperf-lint (Kotlin)"; ok_lint=1
        if ! command -v kotlinc >/dev/null 2>&1; then
          lint="$lint (needs kotlinc)"
        fi
      else
        lint="scaffold"
      fi
      ;;
    objcperf)
      if [[ -f "$dir/objcperf-lint/Makefile" ]] || [[ -f "$dir/objcperf-lint/src/main.c" ]]; then
        lint="objcperf-lint (C scan .m/.h)"; ok_lint=1
        [[ -x "$dir/objcperf-lint/objcperf-lint" ]] && lint="$lint (built)"
      else
        lint="scaffold"
      fi
      ;;
    dartperf)
      if [[ -f "$dir/dartperf-lint/bin/dartperf_lint.dart" ]] || [[ -d "$dir/dartperf-lint" ]]; then
        lint="dartperf-lint (Dart)"; ok_lint=1
        if ! command -v dart >/dev/null 2>&1 && [[ ! -x "${HOME}/dart-sdk/bin/dart" ]]; then
          lint="$lint (needs dart SDK)"
        fi
      else
        lint="scaffold"
      fi
      ;;
    luaperf)
      if [[ -f "$dir/luaperf-lint/luaperf-lint.lua" ]] || [[ -d "$dir/luaperf-lint" ]]; then
        lint="luaperf-lint (pure Lua)"; ok_lint=1
      else
        lint="scaffold"
      fi
      ;;
    beamperf)
      if [[ -f "$dir/beamperf-lint/beamperf_lint.exs" ]] || [[ -d "$dir/beamperf-lint" ]]; then
        lint="beamperf-lint (Elixir+Erlang)"; ok_lint=1
        if ! command -v elixir >/dev/null 2>&1; then
          lint="$lint (needs elixir)"
        fi
      else
        lint="scaffold"
      fi
      ;;
    nimperf)
      if [[ -f "$dir/nimperf-lint/nimperf_lint.nim" ]] || [[ -d "$dir/nimperf-lint" ]]; then
        lint="nimperf-lint (Nim)"; ok_lint=1
        if ! command -v nim >/dev/null 2>&1 && [[ ! -x "${HOME}/.nimble/bin/nim" ]]; then
          lint="$lint (needs nim / choosenim)"
        fi
      else
        lint="scaffold"
      fi
      ;;
  esac

  if [[ "$required" == "1" && "$ok_lint" != "1" ]]; then
    status="incomplete"
    FAIL=1
  fi

  printf '%-12s %-10s %s\n' "$name" "$status" "$lint"
}

echo "== Core kits (required) =="
for p in zperf cperf jsperf jvmperf; do
  check_pkg "$p" 1
done

echo
echo "== Scaffold kits (listed when present; missing OK) =="
for p in goperf pyperf swiftperf arktsperf cppperf csharpperf phpperf rubyperf rustperf kotlinperf objcperf dartperf luaperf beamperf nimperf; do
  if [[ -d "$ROOT/packages/$p" ]]; then
    check_pkg "$p" 0
  else
    printf '%-12s %-10s %s\n' "$p" "absent" "—"
  fi
done

echo
echo "guide-src / examples presence (core):"
for p in zperf cperf jsperf jvmperf; do
  gs="$ROOT/packages/$p/docs/guide-src"
  ex="$ROOT/packages/$p/examples"
  printf '  %s: guide-src=%s examples=%s\n' "$p" \
    "$( [[ -d "$gs" ]] && echo yes || echo no )" \
    "$( [[ -d "$ex" ]] && echo yes || echo no )"
done

if [[ "$FAIL" -ne 0 ]]; then
  echo
  echo "sync-check: FAILED — a core package is missing or lacks its lint entrypoint" >&2
  exit 1
fi
echo
echo "sync-check: OK"
