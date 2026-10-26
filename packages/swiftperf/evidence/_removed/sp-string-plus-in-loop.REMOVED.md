# sp-string-plus-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. `swiftc -O`, Apple Swift 6.3.2. A 50000-character `+=` was slower after `reserveCapacity` (0.585 ms versus 1.117 ms). Thirty-two-character builders repeated 2000 times were also slower with reserve (0.646 ms versus 1.410 ms). Checksums matched. No matcher.

- Slug **never reused**.
- The old blocked note stays beside this file. Fixtures are under `_removed/fixtures/`.
