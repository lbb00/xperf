## 1. Method: measure before changing code

TigerBeetle's TigerStyle order:

1. **Estimate at design time.** Bandwidth and latency for network, disk, memory, and CPU. The largest reported gains (up to 1000×) come from design changes, before profiling is possible.
2. **Fix the slowest resource first** (network > disk > memory > CPU), weighted by frequency. A cache miss repeated often enough can cost as much as an `fsync`.
3. **Batch.** Amortize network, disk, memory, and CPU across batches; give the CPU large, predictable units of work.
4. **Make hot work explicit.** e.g. a hot loop as a standalone function with raw parameters instead of `self` (see §5.6).

Andrew Kelley's *Practical Data-Oriented Design*: **less memory can mean faster code** — fewer allocations and better cache use. This guide starts with memory, then computation.

Sources: [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) · [Practical Data-Oriented Design (Handmade Seattle 2021)](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [Zig PR #7920](https://github.com/ziglang/zig/pull/7920)

