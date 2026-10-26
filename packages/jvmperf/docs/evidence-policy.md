# jvmperf evidence policy

## Gate

A JP rule may be documented / treated as **`error`** (keep / escalate contract for guides and future `--preset`) only if both exist under `packages/jvmperf/evidence/`:

1. `<RULE>.md` — claim, harness, **JDK version + JVM flags** (include `-XX:+UseCompactObjectHeaders` when used), limits
2. `<RULE>.jsonl` — ≥1 before/after measurement pair with fields such as
   `rule`, `case`, `role` (`before` = smell, `after` = fix), `jdk`, `jvm_args`, `ns_per_op` (or `median_ms` / `total_size_bytes`), `alloc_b_per_op`, `ratio`, `ts`

Otherwise the rule stays **`hint`** or **`off`** (a review prompt): fine for dogfood and fixtures, not a “must fix for speed” signal.

CLI may still **exit non-zero on any finding** (unless `--no-fail`); printed severity labels follow this policy table. Full `--preset` wiring is optional later (mirror jsperf/cperf).

## Correlation siblings

- Wall-clock / B/op agreement: `scripts/run-static-vs-hotspot.sh` (writes `research/benches/static-vs-hotspot.{json,jsonl}`)

**Do not** escalate because PrintCompilation / compilation-log line counts look scary — those are noisy (same lesson as V8 `--trace-deopt` counts).

## Current map

As of 2026-10-22 (Asia/Shanghai); benches on JDK 25.0.4.1 + COH. Policy is each rule's default severity in `Rule.java`.

| Rule | Policy | Evidence | Correlate / note |
|------|--------|----------|------------------|
| **jp-boxed-primitive-collection** | **off** | [jp-boxed-primitive-collection](../evidence/jp-boxed-primitive-collection.md) | JDK 27 n=1e6 ~**1.32×**, n=1e5 ~**7.37×**; quiet JDK 21 ~**11×** / ~**8.5×** |
| **jp-string-concat-in-loop** | **error** | [jp-string-concat-in-loop](../evidence/jp-string-concat-in-loop.md) | JDK 27 J23 parts=256 ~**21.3×** |
| jp-regex-in-loop | **off** | [jp-regex-in-loop](../evidence/jp-regex-in-loop.md) | JDK 27 time ~**0.76×**, alloc ~**2.4×**; quiet JDK 21 time ~**1.67×** |
| **jp-format-in-loop** | **off** | [jp-format-in-loop](../evidence/jp-format-in-loop.md) | JDK 27 ~**29×** |
| jp-unpresized-collection | **off** | [jp-unpresized-collection](../evidence/jp-unpresized-collection.md) | JDK 27 n=10k ~**1.43×** |
| **jp-boxed-stream** | **error** | [jp-boxed-stream](../evidence/jp-boxed-stream.md) | JDK 27 boxedReduce/mapToInt ~**37×** |
| **jp-exception-control-flow** | **off** | [jp-exception-control-flow](../evidence/jp-exception-control-flow.md) | JDK 27 ~**4.0×** (spikes); quiet JDK 21 ~**27×** |
| jp-legacy-synchronized-type | **removed** | [tombstone](../evidence/_removed/jp-legacy-synchronized-type.REMOVED.md) | measured ~1.08× / HT negative — matcher deleted |
| jp-many-boolean-fields | **removed** | [tombstone](../evidence/_removed/jp-many-boolean-fields.REMOVED.md) | COH 16=16 no win — matcher deleted |
| **jp-enum-key-hash-collection** | **error** | [jp-enum-key-hash-collection](../evidence/jp-enum-key-hash-collection.md) | JDK 27 EnumMap ~**11.6×** |
| **jp-collection-chain** | **off** | [jp-collection-chain](../evidence/jp-collection-chain.md) | JDK 27 / Kotlin 2.4.21 eager/seq ~**265×** |
| **jp-value-class-boxing** | **hint** | [jp-value-class-boxing](../evidence/jp-value-class-boxing.md) | JDK 27 time ~**4.0×**, alloc ~**5.0×** |
| **jp-lambda-to-non-inline-in-loop** | **off** | [jp-lambda-to-non-inline-in-loop](../evidence/jp-lambda-to-non-inline-in-loop.md) | JDK 27 alloc ~**244×**; time ~**0.47×** |
| jp-lazy-default-mode | **off** | [jp-lazy-default-mode.md](../evidence/jp-lazy-default-mode.md) only | **pending measure** — situational lazy mode |
| **jp-data-copy-in-loop** | **error** | [jp-data-copy-in-loop](../evidence/jp-data-copy-in-loop.md) | JDK 27 time ~**208×**, alloc ~**10001×** |
| jp-android-sparse-array | hint | stub md | **pending** — needs ART/device |
| **jp-log-in-loop** | **off** | [jp-log-in-loop](../evidence/jp-log-in-loop.md) | JDK 27 time mean ~**0.43×** (one spike); quiet JDK 21 ~**18×**; alloc ~**23200 B** |
| jp-sleep-polling | **off** | stub md | **pending** — sleep dominates; design not micro |
| jp-finalize | hint | stub md | **pending** — finalize correctness / Cleaner |
| jp-expensive-alloc-in-loop | **off** | [jp-expensive-alloc-in-loop](../evidence/jp-expensive-alloc-in-loop.md) | tiny-pool **negative** |
| jp-hot-heavy-alloc | **off** | stub md | **pending** — ART/device hot alloc |
| jp-hot-format-log | **off** | stub md | **pending** — ART/device hot format/log |
| jp-hot-system-call | hint | stub md | **pending** — ART/device system call |
| jp-bitmap-decode-no-reuse | hint | stub md | **pending** — ART/device Bitmap |
| jp-hot-post-lambda | hint | stub md | **pending** — ART Handler post |
| jp-ui-text-append | hint | stub md | **pending** — ART UI text |
| **jp-baos-tobytearray-copy** | **error** | [jp-baos-tobytearray-copy](../evidence/jp-baos-tobytearray-copy.md) | JDK 27 toByteArray/writeTo ~**99×** |
| **jp-hot-payload-copy** | **error** | [jp-hot-payload-copy](../evidence/jp-hot-payload-copy.md) | JDK 27 newFrame/reuse ~**158×** |
| vt-unsafe-threadlocal-pool | — (not shipped) | [stub](../evidence/vt-unsafe-threadlocal-pool.md); guide fixtures | guide-first §10.2 |
| **jp-client-factory-recreate** | **error** | [jp-client-factory-recreate](../evidence/jp-client-factory-recreate.md) | JDK 27 HttpClient new+close/reuse ~**1.97e5×** |
| **jp-string-intern-in-loop** | **error** | [jp-string-intern-in-loop](../evidence/jp-string-intern-in-loop.md) | JDK 27 intern/plain ~**6.3×** |
| jp-non-static-field-updater | hint | [jp-non-static-field-updater](../evidence/jp-non-static-field-updater.md) | JDK 27 create ~**526×**; quiet JDK 21 steady-state ~**1.13×** |

**Counts (current defaults):** active rules **29** (was 31; removed jp-legacy-synchronized-type / jp-many-boolean-fields): 8 **error**, 8 **hint**, 13 **off**. The table still lists the tombstones and the not-shipped rule. Default severity follows `Rule.java` / G3 reverse-opt.

## Regenerating

```sh
cd packages/jvmperf
# Lint/tests: JAVA_HOME → JDK 21. Optional benches may use 25:
JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64 bash scripts/run_jmh.sh J32_RuleEvidenceBatch
JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64 bash scripts/run_kotlin_alloc.sh K15
# then refresh evidence/*.jsonl from bench-results if numbers move
```

Re-run after JDK major upgrades. Never invent ratios.

Also see shared [rule-regression.md](../../../docs/rule-regression.md).
