# nm-string-amp-in-loop — string &= in loop

Archived tombstone. The matcher is gone. See [nm-string-amp-in-loop.REMOVED.md](nm-string-amp-in-loop.REMOVED.md).

Nim 2.2.12, `-d:release`, linux x64, load 0.09. Harness: `examples/bench/evidence_nm_amp.nim`.

| role | case | median_ms | ops | ratio |
| --- | --- | ---: | ---: | ---: |
| after | `join` | 0.385 | 20000 | 1 |
| before | `amp_assign` | 0.303 | 20000 | 0.787 |

`join` samples were 0.377–0.402 ms except one 0.452 ms. `&=` samples were 0.294–0.315 ms. An earlier same-day run was 0.694×.
