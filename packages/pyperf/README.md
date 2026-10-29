# pyperf

Python performance notes and `pyperf-lint` (not the PyPI microbenchmark harness).

Part of [XPerf](../../README.md). **Corpus-ready** (G3 2026-10-22). Defaults: pp-str-plus-hot/pp-print-hot **off**, pp-list-plus-rebind **hint**. One rule removed (tombstone, never got a slug).

## Contents

- [English guide](docs/python-performance-guide.md)
- [`pyperf-lint`](pyperf-lint/README.md) — pp-str-plus-hot / pp-list-plus-rebind / pp-print-hot
- [Corpus pins](docs/corpus.md)

## Focus

Prefer `''.join(...)` over `s +=` and `append` over `xs = xs + [...]` in hot loops; keep `print` out of tight loops.

## Run lint

```sh
export PYTHONPATH=packages/pyperf/pyperf-lint
python3 -m pyperf_lint path/to/sources
bash packages/pyperf/scripts/smoke-lint.sh
bash packages/pyperf/scripts/self-lint.sh
```

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         pp-str-plus-hot, pp-list-plus-rebind, pp-print-hot measured (not escalated); PP004 tombstone
examples/         tiny demos + evidence bench
pyperf-lint/      checker (pyperf_lint package) + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
