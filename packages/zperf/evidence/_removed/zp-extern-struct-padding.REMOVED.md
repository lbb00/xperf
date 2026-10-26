# zp-extern-struct-padding — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. Reordering an `extern struct` from 24 bytes to 16 bytes (about **1.5×** smaller) changed a field walk by about **1.21×**. ABI-locked layouts were the usual hit. No matcher.

- Slug **never reused**.
- Historical JSONL and the note stay beside this file. Fixtures are under `_removed/fixtures/`.
