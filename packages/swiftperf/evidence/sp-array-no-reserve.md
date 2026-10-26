# sp-array-no-reserve — measured, still hint

**Status:** measured. Default stays **hint**. The 2026-10-22 corpus verdict does not cover this JSONL.

## Claim

One `Array` of 200000 `Int`s appended without `reserveCapacity` was about **1.6×** the reserved fill (0.293 ms versus 0.180 ms). Thirty-two-element arrays repeated 4000 times were about **5.1×** (1.133 ms versus 0.221 ms). Counts matched.

## How measured

- `swiftc -O`, Apple Swift 6.3.2
- Raw: [`sp-array-no-reserve.jsonl`](sp-array-no-reserve.jsonl)

## Limits

The large fill is modest. The matcher also reports that shape. Do not escalate.
