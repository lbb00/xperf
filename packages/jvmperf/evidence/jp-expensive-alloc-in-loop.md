# jp-expensive-alloc-in-loop — expensive alloc in loop (scope + negative pool myth)

## Claim (rule intent)

Hot construction of **costly reusable** types (`SimpleDateFormat`, `ObjectMapper`, `MessageDigest`, large constant buffers, …) should be lifted / cached. That is what jp-expensive-alloc-in-loop flags.

## Adjacent measurement (do **not** escalate from this alone)

Small escaping objects are a different story: a naive thread-local / recycle **pool of tiny `Point`-like objects can lose wall-clock to plain TLAB `new`** while winning B/op.

- Harness: `J24_PoolVsAlloc.java` / `scripts/run_jmh.sh J24_PoolVsAlloc`
- Compare: `pooled` vs `tlabAlloc` at `batch=1`
- Raw: `research/bench-results/J24_PoolVsAlloc.jsonl`
- Correlate: STATIC-VS-HOTSPOT case 5 **PARTIAL / negative**

| Field | Value |
|-------|--------|
| When | 2026-10-23 Asia/Shanghai |
| JDK | **27 (27+35)** |
| JVM args | `-XX:+UseCompactObjectHeaders` |
| `pooled[batch=1]` | **8.250 ns/op**, **0.000 B/op** |
| `tlabAlloc[batch=1]` | **3.826 ns/op**, **16.000 B/op** |
| **pool / TLAB time** | **~2.16× slower** for the pool |

## Lint mapping

Default severity **off** (run it with `--enable`). Evidence documents **why we do not escalate** jp-expensive-alloc-in-loop to `error` from J24: the rule’s valuable target is expensive factories; J24 warns against reading “always pool” into every `new` in a loop.

## Limits

- No JMH pair yet that isolates `new SimpleDateFormat` in-loop vs `ThreadLocal`/`DateTimeFormatter` on this machine — that would be the positive escalate path.
- VT + fat `ThreadLocal` pools → see guide JP029 (guide-first fixtures), not jp-expensive-alloc-in-loop.
