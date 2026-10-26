# jp-readfile-sync-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [jp-readfile-sync-in-loop.jsonl](jp-readfile-sync-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`fs.readFileSync` of one one-byte file, 2000 times, versus reading once. Node **v26.12.1** on linux x64, load 0.26. Harness: `examples/bench/evidence_jp_readfile.js`. The earlier Node 24 pair was about 480×.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `read_once` | 0.041 | 2000 | 1 |
| before | `read_each_iter` | 4.647 | 2000 | 114.417 |

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Matcher

The checker reports `readFileSync` only in the loop body, after `{`. `for (const line of readFileSync(path).split("\n"))` runs the read once, as the iterable, and is not reported. A path that is the loop binding (`files[i]`) is not reported either. A `while (readFileSync(path))` condition re-reads on every check and is outside the body, so it is not reported. The hint says to hoist only when the path stays the same.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
