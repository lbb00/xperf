# jp-readfile-sync-hot — measured, still hint

## Status
**hint**. Wall-clock JSONL: [jp-readfile-sync-hot.jsonl](jp-readfile-sync-hot.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement
`fs.readFileSync` of one one-byte file, 2000 times, versus reading once. Node **v26.12.1** on linux x64, load 0.26. Harness: `examples/bench/evidence_jp_readfile.js`. The earlier Node 24 pair was about 480×.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `read_once` | 0.041 | 2000 | 1 |
| before | `read_each_iter` | 4.647 | 2000 | 114.417 |

The bench reopens one one-byte file. A path that changes every iteration cannot be hoisted; the measured cost is the open and read. Default stays **hint**. This ratio is not a general speedup.

## Matcher

Default `--scope all` reports `readFileSync` wherever the path looks stable. Under `--scope loop`, only the loop body after `{` matches, so `for (const line of readFileSync(path).split("\n"))` (read once as the iterable) is not reported. A path that is the loop binding (`files[i]`) is not reported either. The hint invites reading once when the path is stable.

## Unblock
Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
