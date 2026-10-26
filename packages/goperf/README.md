# goperf

Go performance notes, small examples, and `goperf-lint` written in **Go**.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). **Corpus-ready** (G3 2026-10-22). Defaults: gp-make-in-loop–gp-fmt-in-loop **off**, gp-append-nil-slice/gp-defer-in-loop **hint**. No invented JSONL.

## Contents

- [English guide (v0)](docs/go-performance-guide.md) — from `docs/guide-src/`
- [`goperf-lint`](goperf-lint/README.md) — gp-make-in-loop–gp-defer-in-loop
- [Corpus pins](docs/corpus.md)

## Focus

Size-hinted empty-slice growth (`make([]T, 0, n)`), `defer` pile-up in loops. Older make/string/fmt loop heuristics remain opt-in after G3 OK-idiom demotion.

## Run lint

```sh
cd packages/goperf/goperf-lint
go build -o goperf-lint ./cmd/goperf-lint
./goperf-lint path/to/sources
./goperf-lint path/to/sources --severity gp-append-nil-slice=error
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
```

Exit `1` only when an **error**-severity finding exists (hints print but exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         per-rule claims + measured JSONL
examples/         tiny Go demos
goperf-lint/      Go checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
