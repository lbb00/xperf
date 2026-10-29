# cp-strcat-hot — measured, stays off

**Status:** measured. Default stays **off** (G3 cold CLI and path builders). Not re-escalated.

## Claim

`strcat` of 500 chunks of 32 bytes, repeated 30 times, was about **221×** an end pointer plus `memcpy` (3.097 ms versus 0.014 ms). Lengths matched.

## How measured

- `clang -std=c11 -O2`
- Raw: [`cp-strcat-hot.jsonl`](cp-strcat-hot.jsonl)

## Limits

The ratio is this fixed chunk repeated onto an empty buffer. A destination that is already at its end, or a single `strcat`, is a different shape.
