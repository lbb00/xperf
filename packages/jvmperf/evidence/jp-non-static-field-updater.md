# jp-non-static-field-updater

## Claim

Non-static `Atomic*FieldUpdater` fields risk per-instance footprint and accidental re-creation. **Creating** an updater each time is ~526× slower than reusing a static one. The JDK 27 steady-state pair (per-instance inc 248 ns, static inc 1567 ns) does not reproduce on a quiet host: Temurin 21.0.13, load 0.96, 4000 passes over 256 nodes, per-instance median 4.747 ms versus static 4.207 ms, about 1.13×. That check does not replace the create-path JSONL. Steady-state stays about 1×.

## How measured

- Source: `J32_RuleEvidenceBatch.jsonl`
- JDK **27 (27+35)**, JVM args `-XX:+UseCompactObjectHeaders`
- **before:** `newUpdaterEach`
- **after:** `staticUpdater`

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| before | **187.165** ns_per_op, **96.003** B/op |
| after | **0.356** ns_per_op, **0.000** B/op |
| **ratio before/after** | **~526×** |

## Lint mapping / policy

Policy **hint** — escalate only if updaters are recreated; common one-per-instance-held pattern is mostly a footprint/style smell, not wall-clock on the inc path.

## Limits

Microbench on this machine; see `scripts/run-static-vs-hotspot.sh`. Do not invent ratios. Corpus residual ≠ speedup.
