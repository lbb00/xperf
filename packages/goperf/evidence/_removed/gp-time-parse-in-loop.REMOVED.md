# gp-time-parse-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. `time.Parse` has no compiled layout to reuse. A fixed timestamp is faster only when the after side does not parse. A changing timestamp cannot be hoisted, and the matcher cannot tell those cases apart.

- Slug **never reused**.
- No active matcher.
