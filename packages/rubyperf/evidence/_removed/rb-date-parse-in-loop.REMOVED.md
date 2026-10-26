# rb-date-parse-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. `Time.parse` on one fixed string was about 604× only because the after side did not parse. A changing string has no parser object to reuse, and the matcher cannot tell those cases apart.

- Slug **never reused**.
- No active matcher.
