# rs-vec-no-capacity — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. A large known-size fill (`Vec::new` plus `push`, N=500000) was about **1.00×** versus `with_capacity`, and live bytes were about **1.05×**. Many small builders were about **2.07×**. The matcher could not tell those apart, and the large fill is the shape the hint was aimed at. No matcher.

- Slug **never reused**.
- Historical JSONL, memory probe, and the note stay beside this file. Fixtures are under `_removed/fixtures/`.

A later quiet rustc 1.99 pair, load 0.03 then 0.11, was 1.007× and 1.000× on the 500000-element fill. The removal stays.
