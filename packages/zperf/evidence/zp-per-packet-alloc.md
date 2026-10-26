# zp-per-packet-alloc — hot-path allocation

## Claim

Per-packet / hot-annotated functions that heap-allocate each call share the same cost model as **zp-alloc-in-loop** (alloc in a hot loop).

## Evidence

No separate microbench: reuse [`zp-alloc-in-loop.md`](zp-alloc-in-loop.md) / [`zp-alloc-in-loop.jsonl`](zp-alloc-in-loop.jsonl) (~**1.4×** GPA alloc+free vs arena retain on this machine; pool/FBA larger — see zp-create-destroy-in-loop/zp-fixed-size-alloc-in-loop).

## Lint mapping

`zperf-lint` zp-per-packet-alloc fires when alloc appears under hot-name / `// zperf-lint: hot` / `--hot-fn` call chains. Severity remains **warning** in rules.zig; treat measured agreement as shared with zp-alloc-in-loop.

## Limits

Hotness heuristics can false-positive; ignore when the allocation is once-per-connection not per-packet.
