# vt-unsafe-threadlocal-pool — not shipped (guide-first)

## Status

**not shipped / guide-only** — no `evidence/vt-unsafe-threadlocal-pool.jsonl`. Do not invent one. Rule is **not** in `Rule.RULES` and has no `bad/`/`good/` lint fixtures.

## Reason

Option B: keep as teaching material until reverse-opt / FP review justifies shipping. Guide fixtures live under:

- `jvmperf-lint/fixtures/guide/vt-unsafe-threadlocal-pool_bad.java` / `vt-unsafe-threadlocal-pool_good.java`
- `jvmperf-lint/fixtures/guide/vt-unsafe-threadlocal-pool_bad.kt` / `vt-unsafe-threadlocal-pool_good.kt`
- `jvmperf-lint/fixtures/guide/README.md`

## Why no JSONL

No shipped rule → no speed gate. Evidence stubs for pending/N/A apply to **shipped** IDs; this file only registers the deliberate absence.

## Unblock

Ship only after guide dogfood + reverse-opt show low FP; then add `bad/`/`good/`, wire `Rule.RULES`, and measure before escalating severity.
