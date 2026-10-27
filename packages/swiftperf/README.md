# swiftperf

Swift performance notes, small examples, and `swiftperf-lint` (Swift Package).

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). The lint is **corpus-ready** for the 2026-10-22 rules (AGENT.md G3). Defaults: sp-array-no-reserve **hint**; sp-print-hot **off**. Force-unwrap, string `+=`, and `map`/`joined` were removed after local `swiftc -O` runs. Three later hints (`sp-dateformatter-hot`, `sp-json-decode-hot`, `sp-regex-hot`) are outside that verdict. Guide v0 scaffold; text-lint parity when Swift SDK is absent.

> **Toolchain:** `swift` may be missing from the machine you run on. Sources + `Package.swift` ship anyway; build with Swift 5.9+ when available. Fixtures and docs are complete without compiling.

## Contents

- [English guide (v0)](docs/swift-performance-guide.md) — from `docs/guide-src/`
- [`swiftperf-lint`](swiftperf-lint/README.md) — sp-array-no-reserve through the hot-call hints (sp-array-no-reserve and the 2026-10-23 hot-call rules hint; print off)
- [Corpus pins](docs/corpus.md)

## Focus

Force-unwrap in hot loops, string concatenation growth, and hot `print`. Claims without a local bench stay provisional.

## Run lint

```sh
cd packages/swiftperf/swiftperf-lint
swift build -c release
"$(swift build -c release --show-bin-path)/swiftperf-lint" path/to/sources
bash ../scripts/smoke-lint.sh
```

Without Swift: `scripts/smoke-lint.sh` runs G0 via [`scripts/text-lint.cjs`](scripts/text-lint.cjs) (heuristic parity with SPM sources). Corpus G2/G3 used the same fallback — see [docs/corpus.md](docs/corpus.md). **corpus-ready: yes** (text-lint parity; re-verify with SPM when a Swift toolchain is available).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         blocked stubs (no JSONL until a Swift toolchain is available)
examples/         tiny Swift demos
swiftperf-lint/   Package.swift + Sources + fixtures
scripts/          smoke-lint.sh, self-lint.sh, text-lint.cjs (fallback without swift)
```
