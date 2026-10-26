# nm-string-amp-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. On Nim 2.2.12, `-d:release`, linux x64, load 0.09, `newSeq` plus `join` was slower than `&=` (**0.787×**, 0.385 ms vs 0.303 ms, N=20000). An earlier run the same day was **0.694×** (0.504 ms vs 0.350 ms). No memory counter showed a ≥2× win for `join`.

- Slug **never reused**.
- No active matcher.
