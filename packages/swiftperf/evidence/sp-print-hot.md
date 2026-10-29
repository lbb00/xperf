# sp-print-hot — measured, stays off

**Status:** measured. Default stays **off**.

## Claim

`print` of 4000 integers, with stdout pointed at `/dev/null`, was about **10×** building the same lines in a `String` (1.475 ms versus 0.148 ms).

## How measured

- `swiftc -O`, Apple Swift 6.3.2
- Raw: [`sp-print-hot.jsonl`](sp-print-hot.jsonl)

## Limits

The after side does not lock stdout. A log line that has to be printed is not this comparison. Leave the default off.
