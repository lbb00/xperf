# cp-strlen-in-cond — measured, still hint

**Status:** measured. Default stays **hint**. Not corpus-triaged.

## Claim

`strlen` in a loop condition is about **125×** a hoisted length when the compiler must assume the string can change (a volatile flag read in the loop, 40 scans of a 1500-byte string). The same spelling on an unchanged string is about **0.93×**: `-O2` already hoists `strlen`. The matcher cannot tell those apart.

## How measured

- `clang -std=c11 -O2`
- Both sides sum the same bytes. The volatile flag stayed 0, so the strings did not change.
- Raw: [`cp-strlen-in-cond.jsonl`](cp-strlen-in-cond.jsonl)

## Limits

Do not read the 125× as the cost of every `strlen` in a condition. An unchanged local string is already hoisted.
