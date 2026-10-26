# rb-hash-merge-in-loop — Hash#merge in loop vs build-once

Archived tombstone. The matcher is gone. See [rb-hash-merge-in-loop.REMOVED.md](rb-hash-merge-in-loop.REMOVED.md). The measurement note below is the old record.

## Claim

**Prior “good” was fix-wrong.** Fixture `base.dup` + `merge!` was **slower** than `base.merge(...)` (~0.60–0.85×) because `merge` already allocates one hash and `dup+merge!` allocates two. **Recommended fix (2026-10-22 land):** build once via Hash literal / assign (no blind `dup`). On Ruby 4.0.8 the wall-clock ratio reversed: `merge` is faster than the literal (**0.784×**, 6.228 ms vs 7.947 ms, N=50000). A second pass the same evening, load average about 24, still had `merge` faster on both medians (**0.645×** and **0.655×**). Samples were noisy; the direction was not. Default stays **`hint`**. Escalate recommended: **no**.

## How measured

- Harness: `packages/rubyperf/examples/bench/evidence_rb.rb` (after arm = `hash_literal_build`)
- Pair A: N=50000 Sidekiq-ish job tagging
- Pair B: N=100 × 200 reps
- Raw: [`rb-hash-merge-in-loop.jsonl`](rb-hash-merge-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| Ruby | **4.0.8** |
| Median before (`hash_merge`) | 6.228 ms |
| Median after (`hash_literal_build`) | 7.947 ms |
| **ratio (before/after)** | **0.784×** (merge faster) |
| Historical wrong-good (`dup_merge_bang`) | ~0.60× at N=50k (after slower) |

## Lint mapping

Keep **`hint`**. Good fixture `rubyperf-lint/fixtures/good/rb-hash-merge-in-loop_merge_bang.rb` now builds via literal (filename kept for smoke stability).

## Limits

- Microbench; `merge!` on a hash you **already uniquely own** (no dup) remains a valid mutate pattern — that is not what the old fixture measured.
- Memory: see [`rb-hash-merge-in-loop.mem.jsonl`](rb-hash-merge-in-loop.mem.jsonl).

## Landed 2026-10-22

fix-wrong: message + fixture + harness after-arm rewritten; wall re-bench ~1.12×. Severity unchanged.

## Memory (2026-10-22)

Ruby 4.0.8, N=50000: `hash_merge` **100005** allocated objects, `dup_merge_bang` **100005**, `hash_literal_build` **200001**. Retained Hash `memsize_of` **8000000** bytes for all three. The literal now allocates about twice as many objects as `merge`, and the wall-clock ratio is **0.784×**. Raw: [`rb-hash-merge-in-loop.mem.jsonl`](rb-hash-merge-in-loop.mem.jsonl).
