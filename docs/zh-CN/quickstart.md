# 快速开始 — 运行代码检查工具

从各自的目录构建并运行每个工具包。不同语言的要求不同；如果本页内容有出入，以工具包的 README 为准。

```sh
# Zig (Zig 0.17+) — package root is zperf-lint/ (build.zig lives there)
# Zig (Zig 0.17+) — package root is zperf-lint/ (build.zig lives there)
cd packages/zperf/zperf-lint && zig build -Doptimize=ReleaseFast
cd packages/zperf/zperf-lint && zig build -Doptimize=ReleaseFast
./zig-out/bin/zperf-lint ../examples
./zig-out/bin/zperf-lint ../examples


# C (C11) — default --preset app
# C (C11) — default --preset app
cd packages/cperf/cperf-lint && make && ./cperf-lint path/to/sources
cd packages/cperf/cperf-lint && make && ./cperf-lint path/to/sources
./cperf-lint path/to/sources --preset all
./cperf-lint path/to/sources --preset all
make self-lint
make self-lint


# JS (Node ≥18, zero npm deps) — default --preset app
# JS (Node ≥18, zero npm deps) — default --preset app
cd packages/jsperf && node jsperf-lint/bin/jsperf-lint.js path/to/sources
cd packages/jsperf && node jsperf-lint/bin/jsperf-lint.js path/to/sources
npm run self-lint
npm run self-lint


# JVM — pin JDK 21 for lint tests (CI uses Temurin 21)
# JVM — pin JDK 21 for lint tests (CI uses Temurin 21)
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64   # adjust to your install
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64   # adjust to your install
cd packages/jvmperf/jvmperf-lint && ./gradlew test jar
cd packages/jvmperf/jvmperf-lint && ./gradlew test jar
bin/jvmperf-lint path/to/sources
bin/jvmperf-lint path/to/sources
# Optional JMH/JOL jars (not in git): bash ../scripts/fetch-lib.sh
# Optional JMH/JOL jars (not in git): bash ../scripts/fetch-lib.sh


# Go
# Go
cd packages/goperf/goperf-lint && go build -o goperf-lint ./cmd/goperf-lint
cd packages/goperf/goperf-lint && go build -o goperf-lint ./cmd/goperf-lint
./goperf-lint path/to/sources
./goperf-lint path/to/sources


# Python (stdlib only)
# Python (stdlib only)
cd packages/pyperf && PYTHONPATH=pyperf-lint python3 -m pyperf_lint path/to/sources
cd packages/pyperf && PYTHONPATH=pyperf-lint python3 -m pyperf_lint path/to/sources


# Swift (needs toolchain; smoke skips if absent)
# Swift (needs toolchain; smoke skips if absent)
cd packages/swiftperf/swiftperf-lint && swift build -c release
cd packages/swiftperf/swiftperf-lint && swift build -c release
"$(swift build -c release --show-bin-path)/swiftperf-lint" path/to/sources
"$(swift build -c release --show-bin-path)/swiftperf-lint" path/to/sources


# ArkTS / HarmonyOS (Node ≥18, zero deps)
# ArkTS / HarmonyOS (Node ≥18, zero deps)
cd packages/arktsperf && node arktsperf-lint/bin/arktsperf-lint.js path/to/sources
cd packages/arktsperf && node arktsperf-lint/bin/arktsperf-lint.js path/to/sources


# C++17
# C++17
cd packages/cppperf/cppperf-lint && make && ./cppperf-lint path/to/sources
cd packages/cppperf/cppperf-lint && make && ./cppperf-lint path/to/sources


# C# (needs dotnet SDK; smoke skips if absent)
# C# (needs dotnet SDK; smoke skips if absent)
cd packages/csharpperf/csharpperf-lint && dotnet run -c Release -- path/to/sources
cd packages/csharpperf/csharpperf-lint && dotnet run -c Release -- path/to/sources


# PHP
# PHP
cd packages/phpperf && php phpperf-lint/phpperf-lint.php path/to/sources
cd packages/phpperf && php phpperf-lint/phpperf-lint.php path/to/sources


# Ruby
# Ruby
cd packages/rubyperf && ruby rubyperf-lint/rubyperf-lint.rb path/to/sources
cd packages/rubyperf && ruby rubyperf-lint/rubyperf-lint.rb path/to/sources


# Rust
# Rust
cd packages/rustperf/rustperf-lint && cargo build --release
cd packages/rustperf/rustperf-lint && cargo build --release
./target/release/rustperf-lint path/to/sources
./target/release/rustperf-lint path/to/sources


# Kotlin (needs kotlinc)
# Kotlin (needs kotlinc)
cd packages/kotlinperf && bash scripts/smoke-lint.sh
cd packages/kotlinperf && bash scripts/smoke-lint.sh


# Objective-C (clang text scan of .m/.h)
# Objective-C (clang text scan of .m/.h)
cd packages/objcperf/objcperf-lint && make && ./objcperf-lint path/to/sources
cd packages/objcperf/objcperf-lint && make && ./objcperf-lint path/to/sources


# Dart (needs dart SDK)
# Dart (needs dart SDK)
cd packages/dartperf/dartperf-lint && dart pub get && dart run bin/dartperf_lint.dart path/to/sources
cd packages/dartperf/dartperf-lint && dart pub get && dart run bin/dartperf_lint.dart path/to/sources


# Lua
# Lua
cd packages/luaperf && lua luaperf-lint/luaperf-lint.lua path/to/sources
cd packages/luaperf && lua luaperf-lint/luaperf-lint.lua path/to/sources


# Elixir / Erlang (beamperf)
# Elixir / Erlang (beamperf)
cd packages/beamperf && elixir beamperf-lint/beamperf_lint.exs path/to/sources
cd packages/beamperf && elixir beamperf-lint/beamperf_lint.exs path/to/sources


# Nim (needs nim)
# Nim (needs nim)
cd packages/nimperf && bash scripts/smoke-lint.sh
cd packages/nimperf && bash scripts/smoke-lint.sh
```

检查软件包是否存在（如果核心工具包缺失，则返回非零值）：

```sh
bash scripts/sync-check.sh
bash scripts/sync-check.sh
```
