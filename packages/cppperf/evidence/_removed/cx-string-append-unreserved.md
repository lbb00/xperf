# cx-string-append-unreserved — string += grow vs reserve (-O2)

## Claim

Measured on this machine (2026-10-22 re-run): primary hot case **`string_plus_grow`** (char/`"x"` append) ratio before/after **~1.09×** (~1×). Earlier fill ~0.97× reverse. Deep-dive: single-char append often **ties or loses** to reserve at `-O2`; **64-byte chunk** append sees reserve win **~1.8–1.9×**. Default stays **`hint`**. Do **not** escalate to `error`.

## How measured

- Harness: `packages/cppperf/examples/bench/evidence_cx.cpp`
- Opt: `O2`
- Deep-dive chunk arm: separate script (case `CX002_chunk64`), not shipped in this repo
- Raw lines: [`cx-string-append-unreserved.jsonl`](cx-string-append-unreserved.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (machine clock; JSONL ts is UTC) |
| Toolchain | **g++ (Debian 14.2.0-19) 14.2.0** |
| Opt | **O2** |
| Median after (`string_reserve_plus`) | 1.162903 ms (ops=200000, ratio=1.000000) |
| Median before (`string_plus_grow`) | 1.263970 ms (ops=200000, ratio=1.086909) |
| **Primary ratio before/after** | **~1.09×** (`string_plus_grow`) |

## Lint mapping

`cppperf-lint` **cx-string-append-unreserved** default stays **`hint`**. Escalate to `error` recommended: **no**. Lint message / docs narrowed to **known final size or multi-byte chunk append** (2026-10-22 deep-dive land).

## Limits

- Fixture uses 1-char append — weak for the smell. Prefer documenting chunk/known-final-size cases.
- The null/reverse deep-dive judged char `+=` scope-narrow / smell-false; only the chunk arm is kept.
- Chunk arm is the intended win; char += is not a speed gate.

## Memory (2026-10-22)

Retained `capacity_bytes`: char grow **245760** vs reserve **200000** (**1.23×**); chunk64 grow **4194304** vs reserve **3200000** (**1.31×**). Chunk arm is the clearer footprint story. [`cx-string-append-unreserved.mem.jsonl`](cx-string-append-unreserved.mem.jsonl).
