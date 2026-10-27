# jp-json-in-loop — measured, still hint

## Status

**hint**. Wall-clock JSONL: [jp-json-in-loop.jsonl](jp-json-in-loop.jsonl). Not corpus-triaged. The 2026-10-22 corpus verdict does not cover this slug.

## Measurement

20000 parses of one fixed JSON text `{"n":1,"s":"hello"}`. Node **v26.12.1** on linux x64, load 0.05. Harness: `examples/bench/evidence_jp_json.js`. The earlier Node 24 pair was about 297×. `JSON.stringify` was not in this rerun.

| role | case | median_ms | ops | ratio |
|------|------|----------:|----:|------:|
| after | `parse_once` | 0.023325 | 20000 | 1 |
| before | `parse_each_iter` | 3.263081 | 20000 | 139.896 |

The microbench shows a cost for this one shape. Default stays **hint** until the shape is corpus-triaged. This ratio is not a general speedup.

## Matcher

The bench parsed one unchanged text. `JSON.parse(rows[i])` and `JSON.parse(line)` in `for (const line of lines)` are a different text every iteration. The checker does not report those. It does not say to fold a JSONL file into one parse. Default `--scope all` reports stable-text JSON calls outside loops too; `--scope loop` keeps the former in-loop-only match. The hint invites reusing results when the text is stable.

## Unblock

Do not set the default to `error` from this file alone. A changing input, a cold path, or another ABI can erase the difference. Corpus triage is still required before any default change.
