# oc-nsstring-append-in-loop — NSString append vs NSMutableString

**Status:** measured (gnustep)

## Claim

GNUstep: `stringByAppendingFormat` in a loop vs `NSMutableString` ~**569×** at N=15000.

## How measured

- Harness: `packages/objcperf/examples/bench/evidence_oc.m`
- Raw lines: [`oc-nsstring-append-in-loop.jsonl`](oc-nsstring-append-in-loop.jsonl)

## Runtime (this evidence file)

| Field | Value |
|-------|--------|
| When | 2026-10-22 Asia/Shanghai (JSONL `ts` is UTC) |
| runtime | **gnustep** |
| Median before (`stringByAppending`) | ~1236 ms |
| Median after (`mutable_string`) | ~2.172 ms |
| **ratio before/after** | **~569×** |

## Lint mapping

`objcperf-lint` oc-nsstring-append-in-loop: default stays **`off`**.

## Limits

- The harness times `stringByAppendingFormat:`; the lint matches `stringByAppendingString` only.
- Strong on GNUstep; Apple runtime may differ. Default stays **off**.
