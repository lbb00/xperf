# luaperf

> **Scope note:** **luaperf** targets **Lua 5.1–5.4** / LuaJIT common patterns. Heuristic lint; measure before escalating.

Lua performance notes, small examples, and `luaperf-lint`.

Part of [XPerf](../../README.md). Shared docs: [docs/README.md](../../docs/README.md). Heuristic lint (**corpus-ready: yes**; **lu-string-concat-hot=error** with G4; lu-table-insert-hot=off; lu-print-hot=hint with G4). Guide v0.

## Contents

- [English guide (v0)](docs/lua-performance-guide.md) — from `docs/guide-src/`
- [`luaperf-lint`](luaperf-lint/README.md) — lu-table-insert-hot–lu-print-hot
- [Corpus pins](docs/corpus.md)

## Focus

Pre-size tables when length is known, prefer table.concat over `..` in loops, keep `print` out of hot loops.

## Run lint

```sh
lua packages/luaperf/luaperf-lint/luaperf-lint.lua path/to/sources
bash packages/luaperf/scripts/smoke-lint.sh
bash packages/luaperf/scripts/self-lint.sh
```

Exit `1` only for **error**-severity findings (hints exit `0` unless `--strict-hints`).

## Layout

```text
docs/guide-src/   chapter sources
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         lu-string-concat-hot measured (error); lu-print-hot measured (hint); lu-table-insert-hot measured (off)
examples/         tiny demos
luaperf-lint/      checker + fixtures
scripts/          smoke-lint.sh, self-lint.sh
```
