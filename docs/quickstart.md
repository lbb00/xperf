# Quick start — run linters

Build and run each kit from its own directory. Requirements differ by language; a kit’s README is authoritative if this page drifts.

```sh
# Zig (Zig 0.17+) — package root is zperf-lint/ (build.zig lives there)
cd packages/zperf/zperf-lint && zig build -Doptimize=ReleaseFast
./zig-out/bin/zperf-lint ../examples

# C (C11) — default --preset app
cd packages/cperf/cperf-lint && make && ./cperf-lint path/to/sources
./cperf-lint path/to/sources --preset all
make self-lint

# JS (Node ≥18, zero npm deps) — default --preset app
cd packages/jsperf && node jsperf-lint/bin/jsperf-lint.js path/to/sources
npm run self-lint

# JVM — pin JDK 21 for lint tests (CI uses Temurin 21)
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64   # adjust to your install
cd packages/jvmperf/jvmperf-lint && ./gradlew test jar
bin/jvmperf-lint path/to/sources
# Optional JMH/JOL jars (not in git): bash ../scripts/fetch-lib.sh

# Go
cd packages/goperf/goperf-lint && go build -o goperf-lint ./cmd/goperf-lint
./goperf-lint path/to/sources

# Python (stdlib only)
cd packages/pyperf && PYTHONPATH=pyperf-lint python3 -m pyperf_lint path/to/sources

# Swift (needs toolchain; smoke skips if absent)
cd packages/swiftperf/swiftperf-lint && swift build -c release
"$(swift build -c release --show-bin-path)/swiftperf-lint" path/to/sources

# ArkTS / HarmonyOS (Node ≥18, zero deps)
cd packages/arktsperf && node arktsperf-lint/bin/arktsperf-lint.js path/to/sources

# C++17
cd packages/cppperf/cppperf-lint && make && ./cppperf-lint path/to/sources

# C# (needs dotnet SDK; smoke skips if absent)
cd packages/csharpperf/csharpperf-lint && dotnet run -c Release -- path/to/sources

# PHP
cd packages/phpperf && php phpperf-lint/phpperf-lint.php path/to/sources

# Ruby
cd packages/rubyperf && ruby rubyperf-lint/rubyperf-lint.rb path/to/sources

# Rust
cd packages/rustperf/rustperf-lint && cargo build --release
./target/release/rustperf-lint path/to/sources

# Kotlin (needs kotlinc)
cd packages/kotlinperf && bash scripts/smoke-lint.sh

# Objective-C (clang text scan of .m/.h)
cd packages/objcperf/objcperf-lint && make && ./objcperf-lint path/to/sources

# Dart (needs dart SDK)
cd packages/dartperf/dartperf-lint && dart pub get && dart run bin/dartperf_lint.dart path/to/sources

# Lua
cd packages/luaperf && lua luaperf-lint/luaperf-lint.lua path/to/sources

# Elixir / Erlang (beamperf)
cd packages/beamperf && elixir beamperf-lint/beamperf_lint.exs path/to/sources

# Nim (needs nim)
cd packages/nimperf && bash scripts/smoke-lint.sh
```

Package presence check (non-zero if a core kit is missing):

```sh
bash scripts/sync-check.sh
```
