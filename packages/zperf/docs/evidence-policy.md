# zperf evidence policy

## Gate

A zperf rule may be documented / treated as a **speed `error`** (cperf/jsperf-style escalate) only if both exist under `packages/zperf/evidence/`:

1. `<RULE>.md` — claim, harness, Zig version / optimize mode, limits
2. `<RULE>.jsonl` — ≥1 before/after line with fields `rule`, `case`, `role`, `zig`, `optimize`, `median_ms`, `ops`, `ratio`, `ts`

Otherwise keep the **rules.zig** severity (`warning` / `info` / `hint` / `off`) and treat as review prompt, not a “must fix for speed” CI gate.

Having JSONL is **necessary, not sufficient**. Escalate only when wall-clock clearly agrees **and** the failure mode matches the rule. Modest ratios, env-dependent I/O, or optimizer-elided benches stay non-error.

CLI today may still fail the process on any finding; this policy is the **keep / escalate** contract until presets land.

## Current map

As of 2026-10-22: measured with Zig **0.17.0** `-Ofast`, median of 9, harness `examples/bench/evidence_fill.zig`.

**G3/r4 (2026-10-22):** several rules demoted to default **`off`** after OK-idiom mass on mature Zig corpora (see [corpus.md](corpus.md); gate definitions in [AGENT.md](../../../AGENT.md)). The evidence JSONL for these rules stays valid; do **not** escalate to `error` without re-validating G4 on the default-on set.

| Rule | rules.zig sev | Evidence | Measured ratio | Escalate? |
|------|---------------|----------|-----------|-----------|
| zp-alloc-in-loop | off | [zp-alloc-in-loop](../evidence/zp-alloc-in-loop.md) | ~**1.4×** GPA vs arena retain | **no** (modest; prefer zp-create-destroy-in-loop / zp-fixed-size-alloc-in-loop for fixed sizes) |
| zp-append-without-reserve | off | [zp-append-without-reserve](../evidence/zp-append-without-reserve.md) | ~**2.1×** | no (info) |
| zp-page-allocator-small | warning | [zp-page-allocator-small](../evidence/zp-page-allocator-small.md) | ~**341×** page vs GPA | **candidate error** |
| zp-print-in-loop | off | [zp-print-in-loop](../evidence/zp-print-in-loop.md) | ~**6e4×** print vs quiet | no — env I/O (like jsperf's jp-console-in-loop) |
| zp-unbuffered-io | off | [zp-unbuffered-io](../evidence/zp-unbuffered-io.md) | ~**49×** empty vs 4KiB | **candidate error** |
| zp-aos-single-field | off | [zp-aos-single-field](../evidence/zp-aos-single-field.md) | ~**6.6×** AoS vs SoA | no (review prompt) |
| zp-bool-array | off | [zp-bool-array](../evidence/zp-bool-array.md) | ~**30×** bool[] vs bitset | no (info) |
| zp-static-string-map | info | [zp-static-string-map](../evidence/zp-static-string-map.md) | ~**2.5×** | no (info) |
| zp-runtime-div-in-loop | off | [zp-runtime-div-in-loop](../evidence/zp-runtime-div-in-loop.md) | ~**12×** mod vs mask | no (review prompt) |
| zp-queue-ordered-remove | warning | [zp-queue-ordered-remove](../evidence/zp-queue-ordered-remove.md) | ~**466×** orderedRemove vs ring | **candidate error** |
| zp-shift-on-read | warning | [zp-shift-on-read](../evidence/zp-shift-on-read.md) | ~**17×** | **candidate error** |
| zp-per-packet-alloc | off | [zp-per-packet-alloc](../evidence/zp-per-packet-alloc.md) | shared zp-alloc-in-loop ~1.4× | no (same as zp-alloc-in-loop) |
| zp-invariant-float-div | hint | [zp-invariant-float-div](../evidence/zp-invariant-float-div.md) | ~**2.0×** | stays hint |
| zp-map-put-without-ensure | off | [zp-map-put-without-ensure](../evidence/zp-map-put-without-ensure.md) | ~**2.8×** | no (info) |
| zp-arena-reset-free-all | warning | [zp-arena-reset-free-all](../evidence/zp-arena-reset-free-all.md) | ~**3.2×** free_all vs retain | borderline warning |
| zp-create-destroy-in-loop | info | [zp-create-destroy-in-loop](../evidence/zp-create-destroy-in-loop.md) | ~**11×** | **candidate error** |
| zp-fixed-size-alloc-in-loop | info | [zp-fixed-size-alloc-in-loop](../evidence/zp-fixed-size-alloc-in-loop.md) | ~**8.5×** | **candidate error** |
| zp-open-file-in-loop | hint | [zp-open-file-in-loop](../evidence/zp-open-file-in-loop.md) | ~**2134×** open once | no (hint; path may change) |
| zp-clock-in-loop | hint | [zp-clock-in-loop](../evidence/zp-clock-in-loop.md) | ~**42×** sample once | no (hint; a fresh timestamp has nothing to hoist) |
| zp-json-in-loop | hint | [zp-json-in-loop](../evidence/zp-json-in-loop.md) | ~**2683×** parse once | no (hint; a changing payload cannot be hoisted) |
| zp-alloc-print-in-loop | hint | [zp-alloc-print-in-loop](../evidence/zp-alloc-print-in-loop.md) | ~**50×** GPA print once; arena ~**12×** | no (hint; a changing value cannot be hoisted) |

### Not measured / N/A this pass

| Rule | Status | Why |
|------|--------|-----|
| zp-debug-allocator | **N/A (static-only)** | Build-mode allocator selection; not one-binary before/after |
| zp-large-struct-by-value | **inconclusive** | ReleaseFast elided by-value vs ptr microbench (~50 ns total) — do not cite |
| zp-missing-free | **N/A (correctness)** | Missing free/deinit — leak/UB, not speed |
| zp-broad-runtime-safety | **pending measure** | Broad `@setRuntimeSafety(false)` — only meaningful under ReleaseSafe |
| zp-packable-bools | **pending measure** | Packable bools — density claim; no wall JSONL yet |
| zp-usize-index-field | **pending measure** | usize index fields — density; no wall JSONL yet |
| zp-catch-unreachable-alloc | **N/A (correctness)** | `catch unreachable` on alloc — UB on OOM |
| zp-oversized-enum-tag | **N/A (static size)** | Oversized enum tag — ABI/size; no wall JSONL |
| zp-optional-scalar-field | **pending measure** | Optional scalar padding — density; no wall JSONL yet |
| zp-catch-unreachable-io | **N/A (correctness)** | `catch unreachable` on I/O |

## Regenerating

```sh
bash packages/zperf/scripts/regen-evidence.sh
```

Re-run after Zig minor upgrades; update matching `.md` medians if ratios move materially.

## Candidate errors (policy, not CLI presets yet)

Strong agreement in these measurements: **zp-page-allocator-small, zp-queue-ordered-remove, zp-shift-on-read, zp-create-destroy-in-loop, zp-fixed-size-alloc-in-loop** (zp-unbuffered-io demoted off after G3 OK-idiom).

Keep as warning/info until `--preset` lands; do not invent `error` in CI without G4 + preset. Default-on after r4: zp-page-allocator-small, zp-broad-runtime-safety, zp-static-string-map, zp-queue-ordered-remove, zp-shift-on-read, zp-invariant-float-div, zp-arena-reset-free-all, zp-create-destroy-in-loop, zp-fixed-size-alloc-in-loop.
