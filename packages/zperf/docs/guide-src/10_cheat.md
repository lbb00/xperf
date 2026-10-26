## 10. Quick reference

**Use less memory**

| Goal | Use |
|---|---|
| Temporary allocations with the same lifetime | `ArenaAllocator` + `reset(.retain_capacity)` |
| Bound retained arena RSS (keepalive) | `reset(.{ .retain_with_limit = N })` (§2.2) |
| No heap allocation | `FixedBufferAllocator` / `ArrayList.initBuffer` |
| Usually small, occasionally large | `BufferFirstAllocator` (0.17) |
| Many objects of one type | `MemoryPool(T)` |
| Equal-size byte buffers | Size-class pool + `tryAlloc` (§2.4) |
| No unpredictable allocation latency | Static allocation + phase wrapper + sized pools (§2.5) |
| Remove padding and traverse by field | `MultiArrayList(T)` |
| Multiple flags | `packed struct(u8)` / `EnumSet` / `bit_set` |
| References | `enum(u32) { none = maxInt(u32), _ }` handles; offsets into relocatable slabs (§2.17) |
| Idle physical reclaim (keep VA) | Compress cold pages + `madvise(DONTNEED)` (§2.17, upstream) |
| Strings | Interning (bytes + `u32` offsets), SSO |
| Map lookup without `dupe` | `getOrPutAdapted` / `StringIndexAdapter` (§2.11) |
| Iterate all map entries | Prefer `ArrayHashMap` when that dominates |
| Optional scalar | Sentinel instead of `?u32` |
| Compile-time-known maps | `EnumArray` / `StaticStringMap.initComptime` |
| Read a large file | `File.createMemoryMap` + zero-copy slices |
| Growable ring | `Deque` (uses `Allocator.remap` when possible) |

**Compute faster**

| Goal | Use |
|---|---|
| Tables or specialization with no runtime cost | `comptime` blocks, `comptime` parameters, `inline for` |
| Data parallelism | `@Vector` + `@reduce`/`@select`/`@shuffle` (LLVM auto-vectorization is disabled in 0.16/0.17) |
| Byte search / compare | `std.mem.findScalar` / `std.mem.eql` (prefer over hand loops) |
| Sort | `std.sort.pdq` (default); see §5.10 |
| Unpredictable branches | `@intFromBool`, `@min`/`@max`, `@select`, `@branchHint(.unpredictable)` |
| State machine or interpreter | Labeled switch with `continue :label` |
| ISA-specific crypto/SIMD in one binary | `builtin.cpu.has` comptime `@import` (§5.2) |
| Cold path | `@branchHint(.cold)` |
| Disable checks locally | `@setRuntimeSafety(false)` in the smallest verified scope |
| Fast floating point | `@setFloatMode(.optimized)`, `@mulAdd` |
| Avoid division | Power-of-two capacity + `&`, compile-time divisor, `@divCeil` |
| Multithreading | `Io.Group.async`, per-task slots, `align(std.atomic.cache_line)` |
| Fewer system calls | Buffered `Io.Writer` + `flush`, `writeSplat` / drain, `Io.Batch`, io_uring |
| Format into memory | `Io.Writer.Allocating` (flush no-op until take) |
| Build options | `-O fast`, `-mcpu`, `-flto`, `-fstrip`, `-fsingle-threaded` |

---

