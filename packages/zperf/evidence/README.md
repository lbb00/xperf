# zperf evidence

Before/after wall-clock gates for `zperf-lint` rules. Policy: [`../docs/evidence-policy.md`](../docs/evidence-policy.md).

## Present (md + jsonl)

[zp-alloc-in-loop](zp-alloc-in-loop.md), [zp-append-without-reserve](zp-append-without-reserve.md), [zp-page-allocator-small](zp-page-allocator-small.md), [zp-print-in-loop](zp-print-in-loop.md), [zp-unbuffered-io](zp-unbuffered-io.md),  [zp-aos-single-field](zp-aos-single-field.md), [zp-bool-array](zp-bool-array.md), [zp-static-string-map](zp-static-string-map.md), [zp-runtime-div-in-loop](zp-runtime-div-in-loop.md), [zp-queue-ordered-remove](zp-queue-ordered-remove.md), [zp-shift-on-read](zp-shift-on-read.md), **[zp-per-packet-alloc](zp-per-packet-alloc.md)** (shares zp-alloc-in-loop numbers), [zp-invariant-float-div](zp-invariant-float-div.md), [zp-map-put-without-ensure](zp-map-put-without-ensure.md), [zp-arena-reset-free-all](zp-arena-reset-free-all.md), [zp-create-destroy-in-loop](zp-create-destroy-in-loop.md), [zp-fixed-size-alloc-in-loop](zp-fixed-size-alloc-in-loop.md).

## pending measure (md stub only — no jsonl)

- **[zp-broad-runtime-safety](zp-broad-runtime-safety.md)** — ReleaseSafe-scoped safety off
- **[zp-packable-bools](zp-packable-bools.md) / [zp-usize-index-field](zp-usize-index-field.md) / [zp-optional-scalar-field](zp-optional-scalar-field.md)** — layout density without a committed bandwidth harness this pass

## N/A (static-only / correctness / static size) — md stub only

- **[zp-debug-allocator](zp-debug-allocator.md)** build-mode GPA selection
- **[zp-missing-free](zp-missing-free.md)** missing free
- **[zp-catch-unreachable-alloc](zp-catch-unreachable-alloc.md)** catch unreachable alloc
- **[zp-oversized-enum-tag](zp-oversized-enum-tag.md)** oversized enum tag (size/ABI)
- **[zp-catch-unreachable-io](zp-catch-unreachable-io.md)** catch unreachable I/O

## inconclusive (md stub only — no jsonl)

- **[zp-large-struct-by-value](zp-large-struct-by-value.md)** large-struct-by-value — ReleaseFast elided the microbench; do not fabricate JSONL

Harness: `../examples/bench/evidence_fill.zig` · regen: `../scripts/regen-evidence.sh`
