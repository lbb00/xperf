# arktsperf

HarmonyOS **ArkTS** performance notes, small examples, and `arktsperf-lint` (pure Node, zero npm deps). ArkTS is TypeScript-like; the checker accepts `.ets`, `.ts`, and `.js`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready** (AGENT.md G3). Defaults: `at-includes-hot` and `at-json-hot` **hint**; `at-alloc-hot` and `at-console-hot` **off**. `at-object-delete` was removed after a Node proxy stayed about 1×. Guide v0 scaffold.

## Contents

- [English guide (v0)](docs/arkts-performance-guide.md) — from `docs/guide-src/`
- [`arktsperf-lint`](arktsperf-lint/README.md) — five rules (see its table for defaults)
- [Corpus pins](docs/corpus.md)

## Focus

Embed / mini-program-like constraints: hot allocation, polymorphic object shapes, and sync bridge / console chatter on the UI or worker hot path. **at-console-hot** (`console.*` in loop) defaults to **off** after G3 (sample noise); enable with `--severity at-console-hot=hint`. Claims without a device or local bench stay provisional. **corpus-ready: yes** — see [docs/corpus.md](docs/corpus.md).

## Run lint

```sh
cd packages/arktsperf
node arktsperf-lint/bin/arktsperf-lint.js path/to/sources
bash scripts/smoke-lint.sh
bash scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule Node-proxy evidence (*.md + *.jsonl)
examples/         tiny ArkTS/TS demos
arktsperf-lint/   pure-JS checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
