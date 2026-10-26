# rb-hash-merge-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. On Ruby 4.0.8 the suggested Hash literal was slower than `Hash#merge` (**0.784×**, 7.947 ms vs 6.228 ms, N=50000) and allocated about twice as many objects (200001 vs 100005). A second pass the same evening, load average about 24, still had `merge` faster (**0.645×** and **0.655×**).

- Slug **never reused**.
- No active matcher.
