# cx-sstream-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. At `-O2`, building an `ostringstream` every iteration versus clearing one stream was **1.24×** (100000 ops, two small insertions). The earlier 1.80× figure was the same shape and still small.

- Slug **never reused**.
- Historical JSONL and markdown stay beside this note. Fixtures moved under `_removed/fixtures/`.
- Gate: a fair microbench that stays near 1× cannot remain an active lint.
