# nimperf

Nim performance notes and same-language `nimperf-lint`.

Part of [XPerf](../../README.md). **Corpus-ready** (G3 2026-10-22). Defaults: nm-seq-add-hot and nm-echo-hot **off**; nm-seq-no-capacity **hint**. `nm-string-amp-in-loop` was removed. Requires `nim` (choosenim).

## Contents

- [English guide (v0)](docs/nim-performance-guide.md) — generated from `docs/guide-src/`
- [`nimperf-lint`](nimperf-lint/README.md) — rules and severities
- [Rule ids](docs/rule-ids.md) · [Evidence policy](docs/evidence-policy.md) · [Corpus pins](docs/corpus.md)

## Run lint

```sh
packages/nimperf/nimperf-lint/nimperf-lint path/to/sources
bash packages/nimperf/scripts/smoke-lint.sh
bash packages/nimperf/scripts/self-lint.sh
```

## Layout

| Path | Contents |
|------|----------|
| `docs/` | guide (`guide-src/` is the source), corpus pins, evidence policy, rule ids |
| `evidence/` | per-rule evidence notes (all pending; see [evidence/README.md](evidence/README.md)) |
| `examples/` | `m01_presize.nim`, `p01_join.nim` |
| `nimperf-lint/` | linter source, fixtures, README |
| `scripts/` | `smoke-lint.sh`, `self-lint.sh` |
