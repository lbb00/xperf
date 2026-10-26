# rs-string-plus-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. `s += "x"` versus `String::with_capacity` was about **1.00×** at N=500000. A 32-byte chunk was about **1.05×**. A tiny repeated builder was about **2.04×**, which is fixed overhead on a short string, not the hot fill. `format!` rebind stays `rs-format-rebind-in-loop`. No matcher.

- Slug **never reused**.
- Historical JSONL and the note stay beside this file. Fixtures are under `_removed/fixtures/`.

A later quiet rustc 1.99 pair, load 0.03 then 0.11, was 1.042× and 1.026× on 500000 `push_str("x")` calls. The removal stays.
