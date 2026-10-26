# pp-datetime-format-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. strptime/strftime on a fixed string was about 172× only because the after side did not parse. A changing input has no compiled-format object to hoist, and the matcher cannot tell those cases apart.

- Slug **never reused**.
- No active matcher.
