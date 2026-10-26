# jp-dom-query-in-loop — measured, still hint

## Status
**hint**. Wall-clock JSONL: [jp-dom-query-in-loop.jsonl](jp-dom-query-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug. Timed with linkedom on a one-element document, not a browser layout tree.

## Measurement
Both sides read `textContent`. Before calls `querySelector(".item")` every iteration. Node **v26.12.1**, linkedom, linux x64, load 0.32. Harness: `examples/bench/evidence_jp_dom.js`. The earlier Node 24 pair was about 8.6×. One once sample was 1.459 ms and one each sample was 17.257 ms; the medians sit in the tighter clusters.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | cached element | 0.924 | 20000 | 1 |
| before | query every iteration | 14.935 | 20000 | 16.169 |

A larger document can move this number. Default stays hint.

## Matcher

The bench repeated one unchanged selector. A selector that names the loop binding (`ids[i]`) is not reported. When the hint fires, it says to cache the node only when the selector stays the same.

## Unblock
Do not set the default to `error` from this file alone. Another input or a cold path can erase the difference. Corpus triage is still required before any default change.
