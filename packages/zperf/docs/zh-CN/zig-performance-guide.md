# zperf：Zig 性能指南

少占内存，提高吞吐。

> **目标版本：Zig 0.17.0。** 示例在 `examples/`，于 **Zig 0.17.0 / x86_64-linux** 上用 `zig test`（Debug 与 `-O fast`）或 `zig build-exe` 校验（`cd examples && zig build test` 可复现）。
> 性能数字来自官方 release notes、原始 PR，或标注为本地实测；没有编造的基准。
>
> 配套：`zperf-lint/` —— 性能/内存反模式静态检查（第 9 章）。

## 目录

- [0. 版本须知：0.14 → 0.17 与性能相关的变化](#0-版本须知014--017-与性能相关的变化)
- [1. 方法论：先度量，再动手](#1-方法论先度量再动手)
- [2. 内存篇](#2-内存篇)
- [3. C 风格省内存技巧在 Zig 中的对应](#3-c-风格省内存技巧在-zig-中的对应)
- [4. 案例：一辆混动车能省多少内存](#4-案例一辆混动车能省多少内存)
- [5. 运算篇](#5-运算篇)
- [6. 并发与 I/O](#6-并发与-io)
- [7. 构建与工具链](#7-构建与工具链)
- [8. 度量与验证](#8-度量与验证)
- [9. zperf-lint：自动找出反模式](#9-zperf-lint自动找出反模式)
- [10. 速查表](#10-速查表)
- [参考资料](#参考资料)

---

## 0. 版本须知：0.14 → 0.17 与性能相关的变化

Zig 未到 1.0，版本可能破坏 API。面向 0.11–0.13 的教程常常编不过。与本文相关的变化如下（来自官方 release notes）：

| 版本 | 变化 | 对本文的影响 |
|---|---|---|
| 0.14 | `@branchHint(.likely/.unlikely/.cold/.unpredictable)` 取代 `@setCold` | 冷路径标注改写法 |
| 0.14 | labeled switch：`continue :label value` | 解释器/状态机的高效分发（tokenizer 因此提速 13%） |
| 0.14 | `GeneralPurposeAllocator` 重写并改名 `DebugAllocator`；新增 `SmpAllocator` | 分配器选择 |
| 0.14 | Allocator vtable 新增 `remap`；`page_allocator` 支持 `mremap` | ArrayList 扩容可能免 memcpy |
| 0.15 | **Writergate**：新 `std.Io.Writer`/`Reader`，缓冲区在接口内，需要手动 `flush` | I/O 缓冲写法全变 |
| 0.15 | `std.ArrayList` 默认变为 unmanaged（不存 allocator）；移除 `BoundedArray`、`LinearFifo`、`RingBuffer` | 容器写法 |
| 0.16 | **I/O as an Interface**：所有 I/O 需要传 `Io`；"Juicy Main" `pub fn main(init: std.process.Init)` | 文件、计时、线程都经由 `Io` |
| 0.16 | 移除 `std.Thread.Pool`，改用 `Io.Group` / `io.async` / `io.concurrent` | 并行写法 |
| 0.16 | `ArenaAllocator` 变为线程安全、无锁；移除 `ThreadSafeAllocator` | arena 可以跨线程共享 |
| 0.16 | `std.mem.indexOf*` 改名 `find*`；hash map 继续 unmanaged 化 | API 改名 |
| 0.16 / 0.17 | **LLVM 循环自动向量化被整体关闭**（规避 LLVM miscompile），预计 0.18 恢复 | 手写 `@Vector` 更重要了 |
| 0.16 | 禁止 packed struct/union 里放指针；禁止运行时向量下标 | packing 写法 |
| 0.17 | `DebugAllocator` 弃用 → `SafeAllocator`（线程安全，带泄漏报告） | Debug 分配器 |
| 0.17 | `StackFallbackAllocator`/`std.heap.stackFallback` → `BufferFirstAllocator` | 小缓冲优化 |
| 0.17 | `@backingInt` / `@fromBackingInt` 取代 `@intFromEnum` / `@enumFromInt`（旧的已弃用，`zig fmt` 自动升级）；新增 `@divCeil` | 句柄/索引写法 |
| 0.17 | 数组乘法 `a ** n` 被移除，改用 `@splat` | 初始化写法 |
| 0.17 | `std.builtin` → `std.lang`；`OptimizeMode` → `Optimize`，tag 改为 `.debug/.safe/.fast/.small`；CLI 为 `-O fast` | 构建脚本 |
| 0.17 | `@bitCast` 重新定义为"逻辑位表示"重解释，不再允许 extern struct；`fmt.allocPrint` → `Allocator.print`；bit_set 改名（`Integer`/`Static`/`Dynamic`） | 位操作、格式化 |

> 小提示：本文示例里凡是写 `// 0.1x:` 的注释，都是在标出版本差异。

来源：[0.14.0 release notes](https://ziglang.org/download/0.14.0/release-notes.html) · [0.15.1 release notes](https://ziglang.org/download/0.15.1/release-notes.html) · [0.16.0 release notes](https://ziglang.org/download/0.16.0/release-notes.html) · [0.17.0 release notes](https://ziglang.org/download/0.17.0/release-notes.html) · [下载页](https://ziglang.org/download/)

---

## 1. 方法论：先度量，再动手

TigerBeetle TigerStyle 的顺序：

1. **设计阶段估算**：网络、磁盘、内存、CPU 的带宽与延迟。最大收益（他们说的“1000×”）往往出现在还无法 profile 的设计阶段。
2. **先处理最慢的资源**（网络 > 磁盘 > 内存 > CPU），并加权频率：频繁的 cache miss 可以贵到接近一次 `fsync`。
3. **批处理**：把网络、磁盘、内存、CPU 成本摊到批次上；给 CPU 大块、可预测的工作。
4. **热点写清楚**：例如把热循环抽成只收原始参数、不带 `self` 的函数（见 §5.6）。

Andrew Kelley *Practical Data-Oriented Design*：**少用内存可以更快**——分配更少、缓存更友好。本文先讲内存，再讲运算。

来源：[TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) · [Practical DOD（Handmade Seattle 2021）](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [Zig PR #7920](https://github.com/ziglang/zig/pull/7920)

---

## 2. 内存篇

### 2.1 选对分配器

Zig 没有全局隐式分配器；会分配的 API 显式接收 `std.mem.Allocator`，调用方可以换分配器而不改业务逻辑。

| 分配器 | 适用 | 注意事项（0.17 源码核实） |
|---|---|---|
| `std.heap.smp_allocator` | ReleaseFast + 多线程的通用 gpa | 全局单例；**每线程按 size-class 的 freelist**；大块 mmap；线程元数据 `align(std.atomic.cache_line)` 防 false sharing（`lib/std/heap/SmpAllocator.zig`）；`assert(!builtin.single_threaded)`。官方：自举时与 glibc malloc 相当 |
| `std.heap.c_allocator` | 已经链接 libc 时 | 只有 `link_libc` 时可用，否则编译错误；直接 malloc/free |
| `std.heap.page_allocator` | 大块、长寿命内存；**作为 arena 的后备** | 每次分配都会按页对齐（`alignForward(n, page_size)`）并发起 mmap 系统调用，**绝不要拿来分配小对象** |
| `std.heap.ArenaAllocator` | 生命周期一致的一批分配（请求、帧、编译单元） | 0.16 起线程安全、无锁；`free` 基本无效，`deinit`/`reset` 一次性回收 |
| `std.heap.FixedBufferAllocator` | 上限已知、零堆分配 | 满了返回 `error.OutOfMemory`；`reset()` O(1) |
| `std.heap.BufferFirstAllocator` | 小对象优化：常见情况走栈缓冲，罕见情况回退 gpa | 0.17 新名字（原 `StackFallbackAllocator`） |
| `std.heap.MemoryPool(T)` | 大量同类型对象频繁创建/销毁 | 内部是 arena + free list；`initCapacity` 预热 |
| `std.heap.SafeAllocator` | Debug / ReleaseSafe：查泄漏、double free、跨实例释放 | 0.17 取代 `DebugAllocator`（已弃用）；`deinit()` 返回泄漏数 |
| `std.heap.wasm_allocator` | WebAssembly | |

**Juicy Main 默认**：`pub fn main(init: std.process.Init)` 拿到的 `init.gpa` 在 Debug/Safe 下是 `SafeAllocator`，在 Fast/Small 下依次选 `c_allocator`（链接 libc 时）→ `wasm_allocator` → `smp_allocator`；`init.arena` 是以 `page_allocator` 为后备的进程级 arena（`lib/std/start.zig`）。

如果要自己选（比如写库的测试 harness，或者不用 Juicy Main）：

> 📄 `examples/m12_gpa_select.zig`（Zig 0.17.0 下 `zig run` 通过）

```zig
const std = @import("std");
const builtin = @import("builtin");

/// 自己选 gpa（不用 Juicy Main 时）：Debug/Safe 用 SafeAllocator 查泄漏，Fast/Small 用 smp_allocator。
/// 0.17: DebugAllocator 已弃用 -> SafeAllocator；builtin.mode 的 tag 在 0.17 改为 .debug/.safe/.fast/.small
var safe_state: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});

pub fn main() !void {
    const gpa, const is_safe = switch (builtin.mode) {
        .debug, .safe => .{ safe_state.allocator(), true },
        // smp_allocator 断言 !single_threaded；单线程构建时退回 page_allocator（与 start.zig 的选择逻辑类似）
        .fast, .small => .{ if (builtin.link_libc) std.heap.c_allocator else if (!builtin.single_threaded) std.heap.smp_allocator else std.heap.page_allocator, false },
    };
    defer if (is_safe) {
        const leaks = safe_state.deinit(); // 报告泄漏并释放后备内存，返回泄漏数
        if (leaks != 0) std.process.exit(1);
    };

    const xs = try gpa.alloc(u64, 1000);
    defer gpa.free(xs);
    @memset(xs, 0); // @memset/@memcpy 会降级为优化过的 memset/memcpy
}
```

**不要这样做**：在库代码里写死某个分配器。库应该接受 `Allocator` 参数，让调用方决定。

来源：[0.14 SmpAllocator/DebugAllocator](https://ziglang.org/download/0.14.0/release-notes.html#SmpAllocator) · [0.16 ArenaAllocator 无锁](https://ziglang.org/download/0.16.0/release-notes.html) · [0.17 SafeAllocator](https://ziglang.org/download/0.17.0/release-notes.html) · `lib/std/heap.zig`、`lib/std/heap/SmpAllocator.zig`、`lib/std/start.zig`（0.17.0）

**证据（本地）：** `examples/p14_alloc_shootout.zig` 对比 smp/c GPA alloc+free、`ArenaAllocator.reset(.retain_capacity)`、`FixedBufferAllocator.reset`（固定 8×64B/请求）。JSONL：`zig-perf-research/bench-results/p14_alloc_shootout.jsonl`（引用前请重跑）。

**SmpAllocator 布局（语料）：** 每个 `Thread` 槽用 `_: void align(std.atomic.cache_line) = {}` 垫开，再放各 size-class 的 `next_addrs` / `frees`（`zig-corpus/zig` @ `8f0c6ce4`，`lib/std/heap/SmpAllocator.zig` 约 L48–95）。与 §6.1 同一课，已写进默认多线程堆。除非要另一套 size-class 策略，否则别自造并行 freelist。

### 2.2 Arena + `reset(.retain_capacity)`：按批复用

请求、帧、批处理这类“一轮一清”的场景：保留一个长寿命 arena，每轮结束调用 `reset(.retain_capacity)`——只把内部指针拨回，已向系统要来的容量留下一轮用。稳态下通常不再打系统调用，也少碎片。

`ArenaAllocator.ResetMode`（Zig 0.17）三种策略：

| 模式 | 效果 | 何时用 |
|---|---|---|
| `.retain_capacity` | 保留已申请容量 | 稳态请求/帧大小 |
| `.retain_with_limit = N` | 同上，但保留上限为 N 字节 | keepalive / 长连接：一次超大 body 不能永久钉住峰值 RSS |
| `.free_all` | 全部还给子分配器 | 关机，或明确要退页 |

无界 `.retain_capacity` 若偶发遇到数兆 body，会**棘轮**抬高 RSS：尖峰过后 arena 仍占着峰值。应给 retain 设上限。http.zig 的 `requestDone` 调用 `req_arena.reset(.{ .retain_with_limit = retain_allocated_bytes })`（默认约数 KiB，可配）。上游 [http.zig#176](https://github.com/karlseguin/http.zig/issues/176) 记录了 retain/池未设上限时并发下 RSS 上涨。

> 📄 `examples/m01_arena.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 每一帧/每个请求都复用同一个 arena：reset(.retain_capacity) 只把指针拨回去，不归还内存。
fn handleRequests(gpa: std.mem.Allocator, requests: []const []const u8) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();

    var total: usize = 0;
    for (requests) |req| {
        // 每轮结束时一次性"释放"本轮全部临时分配
        defer _ = arena_state.reset(.retain_capacity);
        const arena = arena_state.allocator();

        const upper = try arena.alloc(u8, req.len);
        for (upper, req) |*d, s| d.* = std.ascii.toUpper(s);
        const msg = try arena.print("{s}!", .{upper}); // 0.17: fmt.allocPrint -> Allocator.print
        total += msg.len;
    }
    return total;
}

test "arena retain_capacity" {
    const reqs = [_][]const u8{ "get", "post", "delete" };
    try std.testing.expectEqual(@as(usize, 16), try handleRequests(std.testing.allocator, &reqs));
}
```

> 📄 `examples/m16_arena_retain_limit.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// keepalive 风格：retain 设字节上限，避免一次超大请求永久钉住峰值 RSS。
fn handleWithBound(gpa: std.mem.Allocator, bodies: []const []const u8, retain_limit: usize) !usize {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();

    var total: usize = 0;
    for (bodies) |body| {
        defer _ = arena_state.reset(.{ .retain_with_limit = retain_limit });
        const arena = arena_state.allocator();
        const copy = try arena.dupe(u8, body);
        total += copy.len;
    }
    return total;
}

test "arena retain_with_limit" {
    var big: [200]u8 = undefined;
    @memset(&big, 'x');
    const bodies = [_][]const u8{ "small", &big, "again" };
    const n = try handleWithBound(std.testing.allocator, &bodies, 64);
    try std.testing.expectEqual(@as(usize, 5 + 200 + 5), n);
}
```

**证据（上游）：** [http.zig#176](https://github.com/karlseguin/http.zig/issues/176)；http.zig `src/worker.zig` `requestDone` → `retain_with_limit`。**证据（API）：** `lib/std/heap/ArenaAllocator.zig` `ResetMode`。本地 keepalive 后 RSS 微基准仍待补。

**不适用：** 对象寿命互不相关，或需要释放单个对象。长寿命 arena 无 retain 上限时可能无限增长。

### 2.3 FixedBufferAllocator 与 BufferFirstAllocator：栈上的分配器

> 📄 `examples/m02_fba.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

test "FixedBufferAllocator: 零堆分配" {
    var buf: [4096]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);
    const a = fba.allocator();

    var list: std.ArrayList(u32) = .empty;
    try list.appendSlice(a, &.{ 1, 2, 3 });
    try std.testing.expectEqual(@as(usize, 3), list.items.len);

    // 超出缓冲区 -> error.OutOfMemory，而不是去碰堆
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 8192));
    fba.reset(); // O(1) 整体回收
}
```

0.17 的 `BufferFirstAllocator` 把"小对象优化"做成了分配器：先从你给的缓冲区切，不够再交给后备 gpa。

> 📄 `examples/m03_buffer_first.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 0.17: StackFallbackAllocator -> BufferFirstAllocator（"小对象优化"：先用栈缓冲，不够再走 gpa）
fn joinPath(gpa: std.mem.Allocator, parts: []const []const u8) !usize {
    var stack_buf: [256]u8 = undefined;
    var sfa: std.heap.BufferFirstAllocator = .init(&stack_buf, gpa);
    const a = sfa.allocator();
    const joined = try std.mem.join(a, "/", parts);
    defer a.free(joined);
    return joined.len;
}

test "BufferFirstAllocator" {
    try std.testing.expectEqual(@as(usize, 7), try joinPath(std.testing.allocator, &.{ "usr", "bin" }));
    const big: [1000]u8 = @splat('x'); // 0.17 移除了 `**`，用 @splat；超过 256 字节时自动回退到 gpa
    try std.testing.expectEqual(@as(usize, 2001), try joinPath(std.testing.allocator, &.{ &big, &big }));
}
```

**用法。** 栈（或调用方缓冲）按**常见路径**定长——拼路径、短格式化、头解析——后备用长寿命 GPA/arena。装得下就不碰堆；溢出仍可用。实现（`lib/std/heap/BufferFirstAllocator.zig`）：`alloc` 先走 `FixedBufferAllocator`，否则 `fallback.rawAlloc`；`resize`/`remap`/`free` 用固定缓冲的 `ownsPtr` 分流，避免把后备堆块当成栈字节。

| 选择 | 何时 |
|---|---|
| 只用 `FixedBufferAllocator` | 硬上限；OOM 即 bug 或拒绝 |
| `BufferFirstAllocator` | 多数小、偶尔大 |
| 只用 Arena / GPA | 无界或已有池 |

**证据（API / 语料）：** `BufferFirstAllocator.zig` @ `8f0c6ce4`。**证据（本地）：** `m03_buffer_first.zig` 只验证能编过（无计时）。BufferFirst 命中率相对 FBA / GPA 的微基准仍开放（见 `zig-lang-perf-patterns.md`），不要编造命中率。

**注意栈大小**：主线程栈大小由 OS 决定（Linux 上取决于 `ulimit -s`，常见 8 MiB），`std.Thread.spawn` 的线程栈由 `SpawnConfig.stack_size` 决定（0.17 默认 16 MiB）；大缓冲放栈上可能溢出。`zig build-exe -fstack-report` 可以输出每个函数的栈用量诊断，`--stack <size>` 可调主线程栈。

### 2.4 MemoryPool：同类型对象的 O(1) 分配

> 📄 `examples/m04_pool.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Node = struct { value: u64, next: ?*Node };

test "MemoryPool: 定长对象 O(1) 分配/回收，free list 复用" {
    const gpa = std.testing.allocator;
    var pool: std.heap.MemoryPool(Node) = try .initCapacity(gpa, 64); // 预热，避免运行中再申请
    defer pool.deinit(gpa);

    const a = try pool.create(gpa);
    a.* = .{ .value = 1, .next = null };
    pool.destroy(a); // 放回 free list
    const b = try pool.create(gpa); // 复用刚刚释放的槽位
    try std.testing.expect(a == b);
}
```

0.17 的 `memory_pool.Options` 支持 `.growable = false`：预热后冻结容量，配合静态分配策略。Ghostty 写路径在异步 I/O 完成附近用 `std.heap.MemoryPool(Write)` 签出/归还短寿命定长对象（`termio/Exec.zig`）。

#### Size-class 缓冲池（`tryAlloc`）

`MemoryPool(T)` 只管一种类型。服务端常需要大量**等长字节缓冲**（头、body、帧）。预分配 `count` 个长度为 `buf_len` 的缓冲，然后：

1. **`tryAlloc`** — 从池取出或返回 `null`（热路径不回落到堆）。
2. 池空或请求过大 — 动态分配，并计数未命中（http.zig 的 `alloc_buffer_empty` / large-path 指标）。
3. **Release** — 压回 free stack。

常见尺寸走池，离群走别处。争用下的 checkout 是后续问题（[http.zig#199](https://github.com/karlseguin/http.zig/issues/199)）；先把池做对再谈无锁索引。

> 📄 `examples/m15_buffer_pool.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 等长缓冲池 + tryAlloc（热路径不分配）。教学 API，形状参考 http.zig Buffer.Pool。
const BufferPool = struct {
    buffers: [][]u8,
    available: usize,
    buf_len: usize,

    fn init(gpa: std.mem.Allocator, count: usize, buf_len: usize) !BufferPool {
        const buffers = try gpa.alloc([]u8, count);
        errdefer gpa.free(buffers);
        for (buffers) |*slot| slot.* = try gpa.alloc(u8, buf_len);
        return .{ .buffers = buffers, .available = count, .buf_len = buf_len };
    }

    fn deinit(self: *BufferPool, gpa: std.mem.Allocator) void {
        for (self.buffers) |b| gpa.free(b);
        gpa.free(self.buffers);
        self.* = undefined;
    }

    fn tryAlloc(self: *BufferPool) ?[]u8 {
        if (self.available == 0) return null;
        self.available -= 1;
        return self.buffers[self.available];
    }

    fn release(self: *BufferPool, buf: []u8) void {
        std.debug.assert(buf.len == self.buf_len);
        std.debug.assert(self.available < self.buffers.len);
        self.buffers[self.available] = buf;
        self.available += 1;
    }
};

test "buffer pool tryAlloc / release" {
    var pool = try BufferPool.init(std.testing.allocator, 2, 64);
    defer pool.deinit(std.testing.allocator);
    const a = pool.tryAlloc().?;
    const b = pool.tryAlloc().?;
    try std.testing.expect(pool.tryAlloc() == null);
    pool.release(a);
    pool.release(b);
    try std.testing.expect(pool.tryAlloc() != null);
}
```

**证据（上游）：** http.zig `src/buffer.zig`；[http.zig#199](https://github.com/karlseguin/http.zig/issues/199)。**证据（本地）：** `examples/p20_buffer_pool.zig` 对比总是命中的 `tryAlloc`/`release` 与同尺寸 GPA `alloc`+`free`（4 KiB × 200k ops，best-of-7，`-O fast`）。JSONL：`zig-perf-research/bench-results/p20_buffer_pool.jsonl`（引用前请重跑）。未测 miss / 争用 checkout。

### 2.5 静态分配（TigerStyle）

TigerBeetle 规则：**启动时分配全部内存；初始化之后不再分配或释放。** 去掉稳态分配延迟抖动与 use-after-free。队列、循环、连接数都设固定上限。

> 📄 `examples/m11_static.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// TigerStyle 静态分配：启动时按上限一次性分配全部内存，之后只复用、不再分配。
const Server = struct {
    const connections_max = 128;
    const message_size_max = 4096;

    messages: []align(64) [message_size_max]u8,
    free: std.bit_set.Static(connections_max),

    fn init(gpa: std.mem.Allocator) !Server {
        const messages = try gpa.alignedAlloc([message_size_max]u8, .@"64", connections_max);
        return .{ .messages = messages, .free = .full };
    }
    fn deinit(s: *Server, gpa: std.mem.Allocator) void {
        gpa.free(s.messages);
        s.* = undefined;
    }
    fn acquire(s: *Server) ?u32 {
        const i = s.free.findFirstSet() orelse return null;
        s.free.unset(i);
        return @intCast(i);
    }
    fn release(s: *Server, i: u32) void {
        std.debug.assert(!s.free.isSet(i));
        s.free.set(i);
    }
};

test "static allocation" {
    comptime std.debug.assert(Server.message_size_max % 64 == 0);
    var s = try Server.init(std.testing.allocator);
    defer s.deinit(std.testing.allocator);
    const i = s.acquire().?;
    s.messages[i][0] = 42;
    s.release(i);
}
```

#### 用包装分配器强制阶段

TigerBeetle 用 **阶段机**（`StaticAllocator`）包住子分配器：

1. **`init`** — 允许 `alloc` / `resize`（启动接线，含 `errdefer` free）。
2. **`static`** — 经包装的 alloc/resize/free **断言失败**（稳态）。
3. **`deinit`** — 允许 free；禁止 alloc。

打开后调用 `transition_from_init_to_static()`，拆前再切一次。下面是同生命周期的教学桩，不 vendoring TigerBeetle 原类型。

> 📄 `examples/m14_static_phases.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 教学桩：按生命周期阶段断言的分配器（灵感来自 TigerBeetle StaticAllocator）。
const Phase = enum { init, static, deinit };

const PhaseAllocator = struct {
    child: std.mem.Allocator,
    phase: Phase = .init,

    fn allocator(self: *PhaseAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn transitionToStatic(self: *PhaseAllocator) void {
        std.debug.assert(self.phase == .init);
        self.phase = .static;
    }

    fn transitionToDeinit(self: *PhaseAllocator) void {
        std.debug.assert(self.phase == .static);
        self.phase = .deinit;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        std.debug.assert(self.phase == .init);
        return self.child.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *PhaseAllocator = @ptrCast(@alignCast(ctx));
        // init（errdefer）与 deinit 可 free；static 禁止
        std.debug.assert(self.phase != .static);
        self.child.rawFree(memory, alignment, ret_addr);
    }
};

test "phase allocator: alloc only in init" {
    var phase: PhaseAllocator = .{ .child = std.testing.allocator };
    const a = phase.allocator();
    const buf = try a.alloc(u8, 32);
    phase.transitionToStatic();
    phase.transitionToDeinit();
    a.free(buf);
}
```

#### 按并发给对象 / 消息池定容

静态分配只有在池**大到总能推进**时才安全。TigerBeetle 的 `MessagePool` 按最坏并发占用来计：journal 读写 IOPS、pipeline 深度、连接发送队列、grid 修复读，再加一小段突发（+1），避免 parse/ping 卡死副本。定长帧池可按此素描：

1. 列出每个并发持有者（连接 × 在途、磁盘 IOPS、pipeline、循环）。
2. 再加一：持有一条消息的同时申请下一条。
3. 常量允许时 comptime 断言 `messages_max > 1`（及更强不变量）。
4. 若池喂给 Direct I/O / 热 DMA，优先扇区或缓存行对齐。

手工检查（不是 lint）：每个消费者都卡在文档化的最大值时，生产者是否仍能拿到缓冲？不能就提高常量或甩载——不要在 tick 中途分配。

**不适用：** 输入规模未知的工具（编译器、格式转换）。BoundedArray 移除时官方说法：上限只是猜的就别猜——接收调用方缓冲或用动态分配。

**证据（上游）：** TigerBeetle `src/static_allocator.zig`、`src/message_pool.zig`；[TIGER_STYLE Safety](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#safety)。本地稳态 p99 vs 中途 GPA 分配仍待补。

来源：[TigerStyle: Safety](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#safety) · [0.15 removal of BoundedArray](https://ziglang.org/download/0.15.1/release-notes.html) · TigerBeetle `docs/concepts/performance.md`

### 2.6 预留优先（Reserve First）：一次扩容，零失败路径

逐个 `append` 会触发多次扩容和拷贝；更隐蔽的问题是"改到一半 OOM"会让数据结构处于不一致状态。matklad 总结的模式：**先一次性预留，再走不可失败的路径**，并用 `errdefer comptime unreachable` 让编译器证明后面真的不会出错。

> 📄 `examples/m09_reserve_first.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// matklad "Reserve First"：先一次性预留，再走不可失败的路径。
fn appendPair(gpa: std.mem.Allocator, keys: *std.ArrayList(u32), vals: *std.ArrayList(u64), k: u32, v: u64) !void {
    try keys.ensureUnusedCapacity(gpa, 1);
    try vals.ensureUnusedCapacity(gpa, 1);
    errdefer comptime unreachable; // 编译期保证：从这里往下不可能再返回错误
    keys.appendAssumeCapacity(k);
    vals.appendAssumeCapacity(v);
}

test "reserve first" {
    const gpa = std.testing.allocator;
    var keys: std.ArrayList(u32) = .empty;
    defer keys.deinit(gpa);
    var vals: std.ArrayList(u64) = .empty;
    defer vals.deinit(gpa);

    try keys.ensureTotalCapacity(gpa, 1000); // 循环前一次扩容到位
    try vals.ensureTotalCapacity(gpa, 1000);
    for (0..1000) |i| try appendPair(gpa, &keys, &vals, @intCast(i), i * 2);
    try std.testing.expectEqual(@as(u64, 1998), vals.items[999]);
}
```

`zperf-lint` 的 zp-append-without-reserve 规则会检查"for/while 循环里 append 但循环前没 reserve"，包括条件分支里的追加。

#### 按经验比例 `ensureTotalCapacity`（解析器 / IR）

最终长度未知、但对输入大小的**比例稳定**时，按比例预留，别在解析全程靠倍增。Zig 自己的 AST（`lib/std/zig/Ast.zig` @ `8f0c6ce4`）：

- token：`estimated_token_count = source.len / 8`，再 `ensureTotalCapacity`
- 节点：注释写明「经验上 Zig 源码 token:节点 ≈ 2:1」→ `estimated_node_count = (tokens.len + 2) / 2`

对你自己的格式量一次（token/节点 vs 字节），把常数写进代码并注明样本。估错只是多占内存或再扩一次——仍好过巨量输入上无 ensure 的 append。

**证据（语料）：** `Ast.zig` 约 L148–197。**证据（本地）：** 无对 `/8` 的计时；当作 **U** 模式，不是万能常数。

来源：[matklad: Reserve First](https://matklad.github.io/2025/08/16/reserve-first.html) · [matklad: Zig defer Patterns](https://matklad.github.io/2024/03/21/defer-patterns.html) · `lib/std/zig/Ast.zig`

### 2.7 栈上有界列表（BoundedArray 的替代）

> 📄 `examples/m10_stack_list.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

// 0.15 移除 BoundedArray：改用 ArrayList.initBuffer + *Bounded 系列方法
test "栈上有界列表" {
    var buffer: [8]i32 = undefined;
    var stack: std.ArrayList(i32) = .initBuffer(&buffer);
    try stack.appendSliceBounded(&.{ 1, 2, 3 });
    try stack.appendBounded(4);
    try std.testing.expectEqual(@as(usize, 4), stack.items.len);
    try stack.appendSliceBounded(&.{ 5, 6, 7, 8 });
    try std.testing.expectError(error.OutOfMemory, stack.appendBounded(9)); // 满了也不会偷偷上堆
}
```

### 2.8 SoA（MultiArrayList）、bool 移出结构体、冷热分离

AoS（数组的结构体）里每个元素都要为对齐付 padding；SoA 把每个字段存成独立数组，既去掉 padding，又让"只用一两个字段"的循环只加载需要的 cache line。Zig 编译器自己的 token 和 AST 节点就是 SoA：一个 token 只存 1 字节 tag + 4 字节偏移，AST 节点是 1 字节 tag + 4 字节 main_token + 8 字节数据，靠 SoA 避免补齐到 16 字节。

> 📄 `examples/m05_soa.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Monster = struct {
    hp: u32,
    pos: [2]f32,
    kind: enum(u8) { human, orc, elf },
};

test "MultiArrayList: SoA 去 padding、按字段遍历" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Monster) = .empty;
    defer list.deinit(gpa);

    try list.ensureTotalCapacity(gpa, 3);
    list.appendAssumeCapacity(.{ .hp = 10, .pos = .{ 0, 0 }, .kind = .orc });
    list.appendAssumeCapacity(.{ .hp = 20, .pos = .{ 1, 1 }, .kind = .elf });
    list.appendAssumeCapacity(.{ .hp = 30, .pos = .{ 2, 2 }, .kind = .orc });

    const s = list.slice(); // 一次性算出各字段起始指针，循环外取
    var orc_hp: u32 = 0;
    for (s.items(.kind), s.items(.hp)) |k, hp| {
        if (k == .orc) orc_hp += hp; // 只触碰 kind 与 hp 两条紧凑数组
    }
    try std.testing.expectEqual(@as(u32, 40), orc_hp);
    // AoS 每个元素 16 字节（含 3 字节 padding）；SoA 每元素 4+8+1 = 13 字节
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Monster));
}
```

`MultiArrayList` 内部把所有字段数组放在**一次分配**里，并按对齐降序排列子数组；多次访问字段时先 `slice()` 一次，缓存各字段起始指针。

**领域 IR 打包（语料）。** Zig IR（`lib/std/zig/Zir.zig`）指令用 `MultiArrayList`，少见操作数进 `extra: []u32`，文本进 `string_bytes: []u8`。常用 tag 保持密集；稀有载荷离开热 SoA 列。字节码 / AST-extra 同理：常见字段 SoA，其余按索引塞进旁路数组。

**证据（语料）：** `Zir.zig` 字段布局。无本地打包基准。

Andrew 演讲里的两个"不改语义只改布局"的技巧：**把 bool 移出结构体**（用"在哪个数组里"表达它），以及**冷热分离**。

> 📄 `examples/m13_out_of_band.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// Andrew Kelley "Practical DOD"：把 bool 移出结构体 —— 用 "在哪个数组里" 编码它
const Monster = struct { hp: u32, x: u32, y: u32 }; // 12 字节，没有 alive: bool

const World = struct {
    alive: std.ArrayList(Monster) = .empty,
    dead: std.ArrayList(Monster) = .empty,

    fn kill(w: *World, gpa: std.mem.Allocator, i: usize) !void {
        try w.dead.ensureUnusedCapacity(gpa, 1);
        w.dead.appendAssumeCapacity(w.alive.swapRemove(i));
    }
    fn tick(w: *World) void {
        // zperf-lint: ignore zp-aos-single-field -- 示例
        for (w.alive.items) |*m| m.hp -|= 1; // 循环里没有 "if (!alive) continue" 的分支和加载
    }
};

/// 热/冷拆分：每帧都要访问的字段放一起，很少访问的（名字、描述）单独放并用同一索引关联
const Hot = struct { pos: [2]f32, vel: [2]f32 };
const Cold = struct { name: []const u8, created_ms: u64 };

test "out-of-band bool + hot/cold split" {
    const gpa = std.testing.allocator;
    var w: World = .{};
    defer w.alive.deinit(gpa);
    defer w.dead.deinit(gpa);
    try w.alive.appendSlice(gpa, &.{ .{ .hp = 3, .x = 0, .y = 0 }, .{ .hp = 5, .x = 1, .y = 1 } });
    try w.kill(gpa, 0);
    w.tick();
    try std.testing.expectEqual(@as(usize, 1), w.alive.items.len);
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Monster));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Hot));
    _ = Cold;
}
```

**不适用**：总是整体读写一个元素（例如逐个序列化完整记录）时，SoA 反而要访问 N 个数组；元素很少时差别可以忽略。

来源：[Practical DOD](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [演讲文字稿](https://josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod) · [PR #7920 AST 内存布局重做](https://github.com/ziglang/zig/pull/7920) · [Mitchell Hashimoto: Zig Parser](https://mitchellh.com/zig/parser) · `lib/std/multi_array_list.zig`


**证据（本地）：** `examples/p15_soa_bandwidth.zig` — 对 N=4e6 个元素累加一个热 `u32` 字段（4 遍，best-of-7，`-O fast`）：AoS vs `MultiArrayList.items(.hp)` vs 并行 `[]u32`。JSONL：`zig-perf-research/bench-results/p15_soa_bandwidth.jsonl`（引用前请重跑）。

### 2.9 位级压缩：packed struct、任意位宽整数

- `packed struct(uN)` 的字段**按声明顺序从最低位开始**紧密排列，没有 padding，可以和后备整数 `@bitCast` 互转、直接 `==` 比较（0.14+）、做原子操作。
- `u3`、`i7` 这类任意位宽整数**只有在 packed 容器里才真的只占 3/7 位**；在普通 struct 或数组里仍按字节存储（`@sizeOf(u3) == 1`，`@sizeOf([8]u3) == 8`）。
- 0.17 已经没有 `std.PackedIntArray`；需要"N 个 3 位整数紧密排列"时用 `std.mem.readPackedInt` / `writePackedInt`（见第 4 章的完整例子）。

> 📄 `examples/m06_packed.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Flags = packed struct(u8) {
    visible: bool,
    dirty: bool,
    selected: bool,
    layer: u3, // 任意位宽整数
    _pad: u2 = 0,
};

// zperf-lint: ignore zp-packable-bools -- 故意的反例
const Loose = struct { visible: bool, dirty: bool, selected: bool, layer: u8 };

test "packed struct 把 4 个字段压进 1 字节" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Flags));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(Loose));

    var f: Flags = .{ .visible = true, .dirty = false, .selected = true, .layer = 5 };
    f.dirty = true;
    const raw: u8 = @bitCast(f); // 与 u8 互转，可直接原子操作/比较/哈希
    try std.testing.expectEqual(@as(u8, 0b00_101_111), raw);
    try std.testing.expect(f == @as(Flags, @bitCast(raw))); // 0.14+: packed struct 可直接 ==
}

test "u3 等窄整数在普通 struct/数组里仍按字节存储" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(u3));
    try std.testing.expectEqual(@as(usize, 3), @bitSizeOf(u3));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf([8]u3)); // 数组里每个 u3 仍占 1 字节

    // 真正按位压缩：8 个 u3 = 24 bit = 3 字节
    var bytes: [3]u8 = @splat(0);
    for (0..8) |i| std.mem.writePackedInt(u3, &bytes, i * 3, @intCast(i), .little);
    try std.testing.expectEqual(@as(u3, 6), std.mem.readPackedInt(u3, &bytes, 6 * 3, .little));
}
```

**不适用**：频繁单字段读写的热数据——每次读写都要移位和掩码。0.16 起 packed struct/union 里**不能放指针**（需要的话存 `usize`，再 `@ptrFromInt`）。

### 2.10 索引代替指针、句柄、tagged pointer、NaN-boxing

64 位平台上指针是 8 字节，而绝大多数数组用不到 2^32 个元素。用 `u32` 下标（最好包成非穷举 `enum(u32)`，获得类型安全）：省一半空间、可以整体 memcpy/序列化、不怕数组扩容导致指针失效。Zig 编译器的 InternPool 就是让类型和常量都能用 32 位索引引用。TigerStyle 也要求"用 `u32` 这类显式大小的类型，避免依赖架构的 `usize`"。

#### 并发驻留：分片，未命中再加锁（进阶）

编译器 `InternPool`（`src/InternPool.zig` @ `8f0c6ce4`）用**二的幂分片**和每线程 `locals`。查找哈希到分片、`acquire` 共享表，仅在未命中/插入时拿分片互斥（`trackZir` 约 L227+）。索引高位编入线程 id，归属便宜。应用层有争用的字符串/类型池可抄形状：分片 → 共享读 → 插入才加锁——不要每次 intern 抢一把全局锁。

**证据（语料 / U）：** `InternPool.zig` L22–26（shards/locals）、`trackZir`；[PR #15569](https://github.com/ziglang/zig/pull/15569)。本仓库无分片 vs 全局锁本地基准。

> 📄 `examples/m07_index.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 用 u32 句柄代替 *Node：省一半空间、可序列化、可整体 memcpy、天然类型安全
const NodeIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    fn from(i: usize) NodeIndex {
        return @fromBackingInt(@intCast(i)); // 0.17 新增；旧版本用 @enumFromInt
    }
    fn get(self: NodeIndex) u32 {
        return @backingInt(self); // 0.17 新增；旧版本用 @intFromEnum
    }
};

const Node = struct { value: i32, left: NodeIndex, right: NodeIndex };

test "索引代替指针" {
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(Node)); // 指针版 (i32, ?*Node, ?*Node) 是 24
    const nodes = [_]Node{
        .{ .value = 2, .left = .from(1), .right = .none },
        .{ .value = 1, .left = .none, .right = .none },
    };
    try std.testing.expectEqual(@as(i32, 1), nodes[nodes[0].left.get()].value);
}
```

要检测"槽位被复用后旧句柄还在用"（ABA），给句柄加 generation：

> 📄 `examples/x06_generation.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// generation-index 句柄 + free list：检测悬垂引用（ABA），且槽位可复用。
fn SlotMap(comptime T: type, comptime capacity: u32) type {
    return struct {
        const Self = @This();
        pub const Handle = packed struct(u64) { index: u32, generation: u32 };

        items: [capacity]T = undefined,
        generations: [capacity]u32 = @splat(0),
        free: [capacity]u32 = undefined,
        free_len: u32 = 0,
        len: u32 = 0,

        pub fn insert(s: *Self, v: T) ?Handle {
            const i: u32 = if (s.free_len > 0) blk: {
                s.free_len -= 1;
                break :blk s.free[s.free_len];
            } else if (s.len < capacity) blk: {
                s.len += 1;
                break :blk s.len - 1;
            } else return null;
            s.items[i] = v;
            return .{ .index = i, .generation = s.generations[i] };
        }
        pub fn remove(s: *Self, h: Handle) void {
            std.debug.assert(s.generations[h.index] == h.generation);
            s.generations[h.index] +%= 1; // 让旧句柄失效
            s.free[s.free_len] = h.index;
            s.free_len += 1;
        }
        pub fn get(s: *Self, h: Handle) ?*T {
            if (s.generations[h.index] != h.generation) return null;
            return &s.items[h.index];
        }
    };
}

test "generational handles" {
    var map: SlotMap(f32, 4) = .{};
    const a = map.insert(1.5).?;
    map.remove(a);
    const b = map.insert(2.5).?;
    try std.testing.expectEqual(a.index, b.index); // 槽位复用
    try std.testing.expect(map.get(a) == null); // 旧句柄被识破
    try std.testing.expectEqual(@as(f32, 2.5), map.get(b).?.*);
}
```

指针对齐带来的低位恒为 0，可以拿来存 tag：

> 📄 `examples/x05_tagged_ptr.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 利用对齐的低位存 tag：*align(8) T 的低 3 位恒为 0。
const Tag = enum(u3) { leaf, branch, deleted };

const TaggedPtr = packed struct(usize) {
    tag: Tag,
    addr_hi: @Int(.unsigned, @bitSizeOf(usize) - 3), // 0.16: 用 @Int 代替 @Type(.{.int=...})

    fn init(p: *align(8) u64, tag: Tag) TaggedPtr {
        return .{ .tag = tag, .addr_hi = @intCast(@intFromPtr(p) >> 3) };
    }
    fn ptr(self: TaggedPtr) *align(8) u64 {
        return @ptrFromInt(@as(usize, self.addr_hi) << 3);
    }
};

test "tagged pointer" {
    var x: u64 align(8) = 7;
    const tp: TaggedPtr = .init(&x, .branch);
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(TaggedPtr));
    try std.testing.expectEqual(Tag.branch, tp.tag);
    try std.testing.expectEqual(@as(u64, 7), tp.ptr().*);
}
```

解释器常用的 NaN-boxing：把浮点、整数、指针统一塞进 8 字节。

> 📄 `examples/x08_nanbox.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// NaN-boxing：所有值塞进 8 字节 —— 普通 f64 原样存；quiet-NaN 空间的 payload 存 tag + 48 位指针/整数
const Value = packed struct(u64) {
    bits: u64,

    const qnan: u64 = 0x7ff8_0000_0000_0000;
    const tag_int: u64 = 0x0001_0000_0000_0000;
    const tag_ptr: u64 = 0x0002_0000_0000_0000;
    const payload_mask: u64 = 0x0000_ffff_ffff_ffff;

    fn fromFloat(f: f64) Value {
        return .{ .bits = @bitCast(f) }; // 注意：真实实现需把输入 NaN 规范化，避免与 tag 冲突
    }
    fn fromInt(i: u32) Value {
        return .{ .bits = qnan | tag_int | i };
    }
    fn fromPtr(p: *const anyopaque) Value {
        return .{ .bits = qnan | tag_ptr | (@intFromPtr(p) & payload_mask) };
    }
    fn isFloat(v: Value) bool {
        return (v.bits & qnan) != qnan or (v.bits & (tag_int | tag_ptr)) == 0;
    }
    fn isInt(v: Value) bool {
        return (v.bits & (qnan | tag_int | tag_ptr)) == (qnan | tag_int);
    }
    fn asInt(v: Value) u32 {
        return @truncate(v.bits & payload_mask);
    }
    fn asFloat(v: Value) f64 {
        return @bitCast(v.bits);
    }
};

test "NaN-boxing" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Value)); // tagged union 版本通常是 16 字节
    const a: Value = .fromFloat(3.5);
    const b: Value = .fromInt(42);
    try std.testing.expect(a.isFloat() and !a.isInt());
    try std.testing.expectEqual(@as(f64, 3.5), a.asFloat());
    try std.testing.expect(b.isInt() and !b.isFloat());
    try std.testing.expectEqual(@as(u32, 42), b.asInt());
    var x: u32 = 0;
    try std.testing.expect(!Value.fromPtr(&x).isFloat());
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(union(enum) { f: f64, i: u32, p: *anyopaque }));
}
```

**不适用**：tagged pointer / NaN-boxing 依赖地址只用低 48 位等平台假设，调试器也看不懂；只在值表示真的是瓶颈（解释器、VM）时使用。

来源：[InternPool PR #15569](https://github.com/ziglang/zig/pull/15569) · [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) · [0.16 Forbid Pointers in Packed Structs](https://ziglang.org/download/0.16.0/release-notes.html)


当“数组”是一块可重定位、内部混排类型的 mmap slab 时，优先用**相对该基址的字节偏移**，而不是裸指针——见 §2.17。
### 2.11 字符串驻留与小字符串优化

所有字符串追加进一条大 `bytes` 数组，用 `u32` 偏移代表字符串；哈希表只存 `u32`，查找时用 `StringIndexAdapter` 回到 `bytes` 比较。相同字符串只存一次，比较变成整数比较。

> 📄 `examples/m08_intern.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// Zig 编译器同款字符串驻留：所有字符串存进一条 bytes 数组，以 u32 偏移引用；
/// 哈希表只存 u32，靠 StringIndexContext/Adapter 回查 bytes。
const StringPool = struct {
    bytes: std.ArrayList(u8) = .empty,
    table: std.HashMapUnmanaged(u32, void, std.hash_map.StringIndexContext, 80) = .empty,

    fn deinit(p: *StringPool, gpa: std.mem.Allocator) void {
        p.bytes.deinit(gpa);
        p.table.deinit(gpa);
        p.* = undefined;
    }

    fn intern(p: *StringPool, gpa: std.mem.Allocator, s: []const u8) !u32 {
        const gop = try p.table.getOrPutContextAdapted(
            gpa,
            s,
            std.hash_map.StringIndexAdapter{ .bytes = &p.bytes },
            std.hash_map.StringIndexContext{ .bytes = &p.bytes },
        );
        if (gop.found_existing) return gop.key_ptr.*;
        const off: u32 = @intCast(p.bytes.items.len);
        try p.bytes.ensureUnusedCapacity(gpa, s.len + 1);
        p.bytes.appendSliceAssumeCapacity(s);
        p.bytes.appendAssumeCapacity(0); // 以 0 结尾，便于取回
        gop.key_ptr.* = off;
        return off;
    }

    fn get(p: *const StringPool, off: u32) []const u8 {
        const rest = p.bytes.items[off..];
        return rest[0..std.mem.findScalar(u8, rest, 0).?]; // 0.16: indexOfScalar -> findScalar
    }
};

test "string interning" {
    const gpa = std.testing.allocator;
    var pool: StringPool = .{};
    defer pool.deinit(gpa);
    const a = try pool.intern(gpa, "hello");
    const b = try pool.intern(gpa, "world");
    const c = try pool.intern(gpa, "hello");
    try std.testing.expectEqual(a, c);
    try std.testing.expect(a != b);
    try std.testing.expectEqualStrings("world", pool.get(b));
}
```

#### HashMap `*Adapted`：查找时先不拥有 key

`getOrPutAdapted` / `getOrPutContextAdapted`（`lib/std/hash_map.zig`）接受**借用**的 key，以及相对表内 key 类型做 hash/eql 的 adapter。未命中前不必 `alloc.dupe`——踩坑是每次查找都 `dupe` 再 `put`。上面的 `m08_intern.zig` 正是用共享 `bytes` 上的 `StringIndexAdapter`。

若**经常遍历全部条目**，优先考虑 `ArrayHashMap`（键值连续、`swapRemove`）；点查仍是普通 `HashMap` 更合适（相关上游故事见 [Ghostty#2076](https://github.com/ghostty-org/ghostty/pull/2076)，**U**）。

**证据（API / 语料）：** `hash_map.zig` `getOrPutAdapted`（约 L272、L1109）及 std 测试；`m08_intern.zig`。无 Adapted vs dupe 本地微基准。

小字符串优化（SSO）：≤15 字节的字符串直接存在 16 字节的结构体里（和一个切片一样大），不碰堆。

> 📄 `examples/x09_sso.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 小字符串优化（SSO）：≤15 字节内联存储，否则落到堆上。总大小 16 字节。
const SmallString = extern union {
    inline_: extern struct { bytes: [15]u8, len: u8 }, // len 最高位 0 = inline
    heap: extern struct { ptr: [*]u8, len: u32, _pad: [3]u8, tag: u8 }, // tag = 0x80 表示堆

    const heap_tag = 0x80;

    fn init(gpa: std.mem.Allocator, s: []const u8) !SmallString {
        if (s.len <= 15) {
            var r: SmallString = .{ .inline_ = .{ .bytes = undefined, .len = @intCast(s.len) } };
            @memcpy(r.inline_.bytes[0..s.len], s);
            return r;
        }
        const p = try gpa.dupe(u8, s);
        return .{ .heap = .{ .ptr = p.ptr, .len = @intCast(s.len), ._pad = undefined, .tag = heap_tag } };
    }
    fn isHeap(self: *const SmallString) bool {
        return self.inline_.len & heap_tag != 0;
    }
    fn slice(self: *const SmallString) []const u8 {
        return if (self.isHeap()) self.heap.ptr[0..self.heap.len] else self.inline_.bytes[0..self.inline_.len];
    }
    fn deinit(self: *SmallString, gpa: std.mem.Allocator) void {
        if (self.isHeap()) gpa.free(self.heap.ptr[0..self.heap.len]);
        self.* = undefined;
    }
};

test "SSO" {
    const gpa = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(SmallString)); // 与 []const u8 一样大
    var a: SmallString = try .init(gpa, "hello");
    defer a.deinit(gpa);
    var b: SmallString = try .init(gpa, "this string is definitely longer than 15");
    defer b.deinit(gpa);
    try std.testing.expect(!a.isHeap());
    try std.testing.expect(b.isHeap());
    try std.testing.expectEqualStrings("hello", a.slice());
    try std.testing.expectEqualStrings("this string is definitely longer than 15", b.slice());
}
```

### 2.12 可选值、错误联合、切片的隐藏成本

| 类型（x86_64） | `@sizeOf` | 说明 |
|---|---|---|
| `?*T` | 8 | 指针可选：用 null 地址表示，**零额外开销** |
| `?u32` | 8 | 4 字节 + 1 字节标记，按 4 对齐补齐 |
| `?u64` | 16 | 翻倍 |
| `anyerror` | 2 | 默认 u16 错误码 |
| `anyerror!u64` | 16 | |
| `[]u8` | 16 | 指针 + usize 长度（胖指针） |
| `[*:0]const u8` | 8 | 哨兵终止，长度靠扫描 |

热结构体里的 `?u32` 字段改成"哨兵值"（`maxInt(u32)` 表示无，或者 `enum(u32) { none = maxInt(u32), _ }`），省一半。一个"瘦切片" `{ptr, u32 len}` 单独存放时会被对齐吃回 16 字节；真正的收益来自"**偏移 + 长度**指向公共缓冲区"（8 字节），也就是 2.11 的做法。

> 📄 `examples/x01_optional.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

// zperf-lint: ignore zp-optional-scalar-field -- 故意的反例
const WithOpt = struct { parent: ?u32, depth: u32 }; // ?u32 = 4 + 1(flag) -> 对齐到 8
const WithSentinel = struct {
    parent: u32, // maxInt 表示 "无"
    depth: u32,
    const none = std.math.maxInt(u32);
};

test "optional 的代价与哨兵值" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(?u32));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(*u8));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(?*u8)); // 指针可选：null 指针优化，零额外开销
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(WithOpt));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(WithSentinel));
    // 用非穷举 enum 做带哨兵的句柄（见索引示例）也是同样效果
}

test "error union 与切片的大小" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(anyerror)); // 默认 u16 错误码
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(anyerror!u64)); // 8 + 2 -> 对齐 16
    try std.testing.expectEqual(@as(usize, 16), @sizeOf([]u8)); // ptr + usize len
    try std.testing.expectEqual(@as(usize, 8), @sizeOf([*:0]const u8)); // 哨兵终止多项指针：只有 ptr
    // 自定义 "瘦切片"：ptr + u32 len
    const Thin = extern struct { ptr: [*]const u8, len: u32 };
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Thin)); // 单独存时对齐把收益吃掉了……
    const ThinSoA = struct { offset: u32, len: u32 }; // ……改成"偏移+长度"指向公共缓冲区才是 8 字节
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(ThinSoA));
}
```

### 2.13 用枚举容器和编译期表代替哈希表

键是枚举时，`std.EnumArray(E, V)` 就是一个 `[N]V`，`std.EnumSet(E)` 是一个位集，`std.EnumMap` 是位集 + 数组——都没有哈希、没有分配。键是编译期已知的字符串时，用 `std.StaticStringMap(V).initComptime`（按长度分桶的只读表）。

> 📄 `examples/x02_enum_containers.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Kind = enum { int, float, string, bool };

const keywords = std.StaticStringMap(Kind).initComptime(.{
    .{ "int", .int },
    .{ "float", .float },
    .{ "string", .string },
    .{ "bool", .bool },
});

test "EnumArray 代替 HashMap(enum, V)" {
    var counts: std.EnumArray(Kind, u32) = .initFill(0); // 就是一个 [4]u32
    counts.getPtr(.float).* += 1;
    try std.testing.expectEqual(@as(u32, 1), counts.get(.float));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(@TypeOf(counts)));
}

test "StaticStringMap：编译期构建的只读字符串表（按长度分桶），零运行时分配" {
    try std.testing.expectEqual(Kind.float, keywords.get("float").?);
    try std.testing.expect(keywords.get("double") == null);
}
```

### 2.14 零拷贝：切片指向输入、内存映射文件

解析时返回指向输入缓冲区的切片而不是 `dupe`，输入缓冲区本身用 mmap，整个流程可以做到不拷贝文件内容。0.16 起 `Io.File.createMemoryMap` 是跨平台封装（底层仍有 `std.posix.mmap`）。

> 📄 `examples/x03_zero_copy.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 零拷贝解析：结果切片直接指向输入缓冲区，不 dupe。
const Field = struct { key: []const u8, value: []const u8 };

fn parseLine(line: []const u8) ?Field {
    const eq = std.mem.findScalar(u8, line, '=') orelse return null; // 0.16: indexOfScalar -> findScalar
    return .{
        .key = std.mem.trim(u8, line[0..eq], " "),
        .value = std.mem.trim(u8, line[eq + 1 ..], " "),
    };
}

test "zero-copy" {
    const input = "name = zig\nversion= 0.17\n";
    var it = std.mem.splitScalar(u8, input, '\n');
    var n: usize = 0;
    while (it.next()) |line| {
        const f = parseLine(line) orelse continue;
        // 切片指针落在 input 内部 —— 没有发生拷贝
        try std.testing.expect(@intFromPtr(f.key.ptr) >= @intFromPtr(input.ptr));
        n += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), n);
}
```

> 📄 `examples/x07_mmap.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

// 0.16+: File.MemoryMap（跨平台的 mmap 封装）；也可直接 std.posix.mmap。
test "memory-mapped file" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(io, "data.bin", .{ .read = true });
    defer file.close(io);
    try file.writeStreamingAll(io, "hello mmap");

    var map = try file.createMemoryMap(io, .{ .len = 10, .protection = .{ .read = true } });
    defer map.destroy(io);
    try std.testing.expectEqualStrings("hello mmap", map.memory[0..10]);
}
```

**注意**：零拷贝意味着结果的生命周期绑定在输入缓冲区上；mmap 的文件被其他进程截断时访问会触发 SIGBUS。

### 2.15 变长编码与差分

有序 ID、时间戳这类单调序列，先做差分再用 LEB128 变长编码，小差值只占 1 字节。`std.Io.Writer.writeUleb128` / `std.Io.Reader.takeLeb128` 直接支持。

> 📄 `examples/x04_varint.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 差分 + LEB128 变长编码：单调递增的 id 序列通常可以压到每个 1~2 字节。
fn encode(w: *std.Io.Writer, ids: []const u64) !void {
    var prev: u64 = 0;
    for (ids) |id| {
        try w.writeUleb128(id - prev);
        prev = id;
    }
}

fn decode(r: *std.Io.Reader, out: []u64) !void {
    var prev: u64 = 0;
    for (out) |*o| {
        prev += try r.takeLeb128(u64);
        o.* = prev;
    }
}

test "delta + varint" {
    const ids = [_]u64{ 1_000_000, 1_000_003, 1_000_010, 1_000_200 };
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try encode(&w, &ids);
    try std.testing.expectEqual(@as(usize, 3 + 1 + 1 + 2), w.end); // 7 字节 vs 原始 32 字节

    var r: std.Io.Reader = .fixed(w.buffered());
    var out: [4]u64 = undefined;
    try decode(&r, &out);
    try std.testing.expectEqualSlices(u64, &ids, &out);
}
```

### 2.16 碎片、大页与其他

- **碎片**：大量不同大小、不同寿命的小对象混在一个通用堆里最容易产生碎片。按生命周期分组（arena）、按大小分组（MemoryPool）、或者静态分配，都能从根上避免。
- **大页（huge pages）**：大块、随机访问的内存（哈希表、大数组）上 TLB miss 可能是瓶颈。Linux 上可以对 mmap 出来的区域 `madvise(MADV_HUGEPAGE)` 使用透明大页；是否有收益必须实测（`perf stat -e dTLB-load-misses`）。
- **ArrayList 扩容**：0.14 起 Allocator 有 `remap`，`page_allocator` 支持 `mremap`，所以大 ArrayList 扩容时可能由内核重映射页而不是 memcpy。
- **`Deque` + `remap`：** `std.Deque` 扩容尽量走 `Allocator.remap`，环能原地长大才拆 head/tail 搬迁（`lib/std/deque.zig`）。大环后面用支持 remap 的分配器更合适。

---

### 2.17 可重定位 slab 与空闲物理页回收（进阶）

#### 在基址上存偏移，不存裸指针

区域需要**移动、快照或原地压缩**时，内部指针会悬空。Ghostty 终端页在整块 slab 上存类型化的**字节偏移**（`Offset(T)`），而不是 `*T`。解析为 `base + byte`（带对齐断言）；搬迁只需字节拷贝或 remap，不必走指针图。与 §2.10 索引同一思路；这里的“数组”是混排布局的不透明 mmap 页（cell、style、grapheme）。

匿名 `mmap`（`MAP_PRIVATE|MAP_ANONYMOUS`）常作 slab 来源：页对齐、OS 填零，大页上没有通用分配器 freelist 开销（与 zp-page-allocator-small“别拿 `page_allocator` 分小对象”互补）。

> 📄 `examples/m17_offset_slab.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 可重定位基址上的类型化字节偏移（不存裸指针）。教学 API，形状参考 Ghostty Offset(T)。
fn Offset(comptime T: type) type {
    return struct {
        byte: u32 = 0,
        const Self = @This();
        fn ptr(self: Self, base: []u8) [*]T {
            const addr = @intFromPtr(base.ptr) + self.byte;
            std.debug.assert(addr % @alignOf(T) == 0);
            return @ptrFromInt(addr);
        }
        fn slice(self: Self, base: []u8, len: usize) []T {
            return self.ptr(base)[0..len];
        }
    };
}

const Cell = struct { ch: u32, style: u16 };

test "offset into relocatable slab" {
    var slab: [256]u8 align(@alignOf(Cell)) = undefined;
    const off: Offset(Cell) = .{ .byte = 0 };
    const cells = off.slice(slab[0..], 4);
    cells[0] = .{ .ch = 'A', .style = 1 };
    cells[1] = .{ .ch = 'B', .style = 2 };
    var moved: [256]u8 align(@alignOf(Cell)) = undefined;
    @memcpy(moved[0..], slab[0..]);
    const again = off.slice(moved[0..], 4);
    try std.testing.expectEqual(@as(u32, 'A'), again[0].ch);
    try std.testing.expectEqual(@as(u32, 'B'), again[1].ch);
}
```

#### 保留虚拟映射、丢掉空闲物理页

冷数据可以保留**虚拟地址**、丢掉**物理页**。Ghostty 回滚路径对空闲终端页做 LZ4 压缩、保留映射，再在 Linux 上 `MADV_DONTNEED`（Darwin 有对应 reusable-free），RSS 下降且恢复时不必重新申请。上游 [ghostty#13264](https://github.com/ghostty-org/ghostty/pull/13264) 报告约 **70–90%** 物理节省（重复语料可达 ~94%），增量空闲回收约 ~100 µs/页——这些是**上游测量**，本仓库尚未复现 ScrollbackCompression 式基准前不要当本地数字引用。

设计约束：

1. 压缩器优先看**压缩比与解压吞吐**，而不是花哨 SIMD 比较。
2. 只有比常驻更省内存时才保留压缩形态。
3. 恢复须先 recommit/fault，读者才能再碰数据。

**证据（上游）：** Ghostty `src/terminal/size.zig` / `page.zig`；`src/terminal/compress/Page.zig` + [PR #13264](https://github.com/ghostty-org/ghostty/pull/13264)。**证据（本地）：** `m17_offset_slab.zig` 只教偏移 API（无计时）。

**不适用：** 压缩+madvise 成本超过空闲窗口的短寿命堆；没有可靠 decommit 原语的平台。

---

## 3. C 风格省内存技巧在 Zig 中的对应

很多嵌入式 / 内核里的 C 省内存手法，在 Zig 里都有更安全、布局更确定的对应物。

| C 写法 | Zig 对应 | 关键差别 |
|---|---|---|
| `enum Color {...}`（通常 `int` 大小，实现定义） | `enum { ... }` 自动推断最小 tag（3 个值 → `u2`）；或显式 `enum(u8)` | 存储时仍按字节，但放进 packed struct 只占 tag 位宽 |
| 位域 `unsigned x:4;` | `packed struct(u16) { x: u4, ... }` + 任意位宽 `uN`/`iN` | C 位域的位序/跨单元规则由实现定义；Zig 规定**第一个字段在最低位**，跨平台一致 |
| 按位标志 `#define F_A 1<<0` + `unsigned flags` | `packed struct(u8)` 的 bool 字段；`std.EnumSet(E)`；`std.bit_set.Integer(N)` / `Static(N)` / `Dynamic` | 类型安全，不会把错误的标志或错误的枚举混进来 |
| `sizeof` / `_Alignof` / `offsetof` | `@sizeOf` / `@alignOf` / `@offsetOf`；另有 `@bitSizeOf`、`@bitOffsetOf` | 位级查询是 C 没有的 |
| `struct` 按声明顺序布局 | 普通 `struct`：**编译器可以重排**字段；`extern struct`：按 C ABI 声明顺序 | 只有 extern struct 需要手动排序字段 |
| `#pragma pack(1)` / `__attribute__((packed))` | `extern struct` + 字段级 `align(1)`；或 `packed struct` | 非对齐访问可能更慢 |
| `union` | `extern union`（C 兼容，可类型双关）；裸 `union`（Debug/Safe 有隐藏安全 tag）；`union(enum)`（显式 tag） | tagged union 的 tag 会按 payload 对齐补齐 |
| `signed`/`unsigned` 的选择 | 同样按值域选：`i7` 是 [-64, 63]，`u7` 是 [0, 127] | Zig 默认溢出是安全检查（Debug/Safe panic），要回绕用 `+%` |
| 字节 vs 位 | `bool` 占 1 字节；`[N]bool` 占 N 字节；位集占 N/8 字节 | 大量标志用位集省 8 倍 |

### 3.1 enum 的 tag 宽度

> 📄 `examples/c01_enum_width.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

// C: enum Color { RED, GREEN, BLUE };  sizeof == sizeof(int) == 4（实现相关）
const Color = enum { red, green, blue }; // Zig 自动推断最小 tag：u2
const Opcode = enum(u8) { nop, add, sub, _ }; // 显式 tag，非穷举 `_` 便于从字节流解码

test "enum 大小" {
    try std.testing.expectEqual(u2, @typeInfo(Color).@"enum".tag_type);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Color)); // 存储仍按字节
    try std.testing.expectEqual(@as(usize, 2), @bitSizeOf(Color)); // 但在 packed struct 里只占 2 bit
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Opcode));
    const op: Opcode = @fromBackingInt(@as(u8, 200)); // 非穷举 enum 允许未命名值
    try std.testing.expect(op != .add);
}
```

### 3.2 位域 → packed struct

> 📄 `examples/c02_bitfield.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

// C:
// struct Hdr { unsigned version:4; unsigned ihl:4; unsigned dscp:6; unsigned ecn:2; };
// C 位域的位序、跨字节规则由编译器/ABI 决定；Zig packed struct 的规则是确定的：
// 第一个字段放在后备整数的最低位。
const Hdr = packed struct(u16) {
    ihl: u4,
    version: u4,
    ecn: u2,
    dscp: u6,
};

const Signedness = struct { delta: i7, count: u7 };

test "packed struct 等价 C 位域" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Hdr));
    try std.testing.expectEqual(@as(usize, 16), @bitSizeOf(Hdr));
    try std.testing.expectEqual(@as(u16, 8), @bitOffsetOf(Hdr, "ecn"));
    const h: Hdr = .{ .version = 4, .ihl = 5, .dscp = 0, .ecn = 0 };
    const raw: u16 = @bitCast(h);
    try std.testing.expectEqual(@as(u16, 0x45), raw);
    // 0.17: 也可以用 @backingInt 取后备整数
    try std.testing.expectEqual(raw, @backingInt(h));
    // 有符号 i7 范围 [-64, 63]，无符号 u7 范围 [0, 127]——按值域选类型
    try std.testing.expectEqual(@as(i7, -64), std.math.minInt(i7));
    try std.testing.expectEqual(@as(u7, 127), std.math.maxInt(u7));
    _ = Signedness;
}
```

### 3.3 sizeof/alignof/offsetof 与 `#pragma pack`

> 📄 `examples/c03_layout.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

// C 的 struct 按声明顺序布局；Zig 普通 struct 不保证顺序（编译器可重排），
// extern struct 才与 C ABI 一致，需要手动排序字段。
// zperf-lint: ignore zp-extern-struct-padding -- 故意的反例
const Bad = extern struct { a: u8, b: u64, c: u8 }; // 1 + 7pad + 8 + 1 + 7pad = 24
const Good = extern struct { b: u64, a: u8, c: u8 }; // 8 + 1 + 1 + 6pad = 16
const Auto = struct { a: u8, b: u64, c: u8 }; // 编译器自行重排

// #pragma pack(1) 的对应：字段级 align(1)
const Packed1 = extern struct { a: u8, b: u32 align(1) };

test "sizeof/alignof/offsetof 对应" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(Bad));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Good));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(Bad, "b"));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(Good));
    try std.testing.expect(@sizeOf(Auto) <= 16);
    try std.testing.expectEqual(@as(usize, 5), @sizeOf(Packed1));
    try std.testing.expectEqual(@as(usize, 1), @offsetOf(Packed1, "b"));
}
```

`zperf-lint` 的 zp-extern-struct-padding 规则会计算 extern struct 当前大小与重排后大小，例如上面的 `Bad` 会被报告"当前 24 字节，按对齐降序重排后 16 字节"。

### 3.4 union：C union、裸 union、tagged union

> 📄 `examples/c04_union.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Untagged = union { i: u32, f: f32 }; // 无 tag；Debug/ReleaseSafe 下编译器会加隐藏安全 tag
const Tagged = union(enum) { i: u32, f: f32 }; // 显式 tag：+1 字节 tag，再按对齐补齐
const CUnion = extern union { i: u32, f: f32 }; // 与 C union 一致，可做类型双关

test "union 开销" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Tagged)); // 4 + tag(1) + 3 pad
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(CUnion));
    const u: CUnion = .{ .f = 1.0 };
    try std.testing.expectEqual(@as(u32, 0x3f800000), u.i); // extern union 读另一个字段是合法的
    _ = Untagged;
}

// 大量 tagged union 时，把 tag 拆出去（MultiArrayList 对 union 自动拆成 tags + data 两条数组）
test "MultiArrayList(tagged union) 拆 tag" {
    const gpa = std.testing.allocator;
    var list: std.MultiArrayList(Tagged) = .empty;
    defer list.deinit(gpa);
    try list.append(gpa, .{ .i = 1 });
    try list.append(gpa, .{ .f = 2.0 });
    try std.testing.expectEqual(@as(usize, 2), list.items(.tags).len);
    try std.testing.expectEqual(Tagged{ .f = 2.0 }, list.get(1));
}
```

**注意**：0.17 起 `@bitCast` 不再接受 extern struct；要做内存层面的类型双关，用 `@ptrCast` 或 `extern union`。

### 3.5 标志集合：EnumSet 与 bit_set

> 📄 `examples/c05_flags.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Perm = enum { read, write, exec, admin };

test "flags：EnumSet / bit_set" {
    // C: #define READ 1, WRITE 2 ... ; unsigned flags;
    var p: std.EnumSet(Perm) = .empty; // 0.17: initEmpty -> .empty
    p.insert(.read);
    p.insert(.exec);
    try std.testing.expect(p.contains(.exec));
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(std.EnumSet(Perm)));

    var small: std.bit_set.Integer(64) = .empty; // 一个 u64
    small.set(63);
    try std.testing.expectEqual(@as(usize, 1), small.count());

    var big: std.bit_set.Static(1000) = .empty; // >64 位时自动变成 [N]usize 数组
    big.set(999);
    try std.testing.expectEqual(@as(?usize, 999), big.findFirstSet());

    // 运行时长度：Dynamic（0.17 起不带 allocator 字段）
    const gpa = std.testing.allocator;
    var dyn: std.bit_set.Dynamic = try .initEmpty(gpa, 10_000);
    defer dyn.deinit(gpa);
    dyn.set(1234);
    try std.testing.expect(dyn.isSet(1234));
    // 对比：[10_000]bool 占 10_000 字节；bit set 占 10_000/8 ≈ 1250 字节
}
```

来源：[Zig 语言参考 0.17.0](https://ziglang.org/documentation/0.17.0/) · [0.17 @bitCast changes](https://ziglang.org/download/0.17.0/release-notes.html) · [0.17 bit_set 改名](https://ziglang.org/download/0.17.0/release-notes.html) · `lib/std/enums.zig`、`lib/std/bit_set.zig`

---

## 4. 案例：一辆混动车能省多少内存

> 本节的思路来自抖音视频「写代码省内存」（刘严鹏）：<https://v.douyin.com/KoVqTHbb9L0/>。下面用 Zig 把视频里的四步走一遍，每一步的大小都由 `@sizeOf` / `@bitSizeOf` 在测试里断言过。

视频里的 C 代码分四步：

1. `enum Car { ELECTRIC = 1, BENZINE = 2, DIESEL = 3 };`
2. 混动车用两个 `int` 存两种动力：`struct { int type1; int type2; }`，`sizeof` 为 8 字节（64 位）。
3. 改成位标志：`ELECTRIC = 1, BENZINE = 1 << 1, DIESEL = 1 << 2`，`int types = ELECTRIC | BENZINE;`，4 字节。
4. 改成位域：`struct { uint8_t electric:1; uint8_t benzine:1; uint8_t diesel:1; }`，`sizeof` 为 1 字节。

| 步骤 | C | Zig 对应 | 大小 |
|---|---|---|---|
| 两个 int | `struct { int type1, type2; }` | `extern struct { type1: CarC, type2: CarC }`（`enum(c_int)`） | 8 字节 |
| 小 tag | — | `struct { type1: Car, type2: Car }`，`Car = enum(u2)` | 2 字节（`@bitSizeOf(Car) == 2`） |
| 位标志 | `unsigned int` | `c_uint` 常量按位或 | 4 字节 |
| 位域 | `uint8_t x:1` ×3 | `packed struct(u8) { electric: bool, benzine: bool, diesel: bool, _pad: u5 = 0 }` | 1 字节（8 bit，3 bit 有效） |
| 位集 | — | `std.EnumSet(FuelKind)` | 1 字节 |
| 1000 辆车 | — | 每辆 3 bit 紧密排列（`readPackedInt`/`writePackedInt`） | 375 字节（对比 `[1000]Fuel` 1000 字节、两个 int 版本 8000 字节） |

> 📄 `examples/c06_car_case.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

// 第 1/2 步  C: enum Car { ELECTRIC=1, BENZINE=2, DIESEL=3 }; struct { int type1; int type2; }
const CarC = enum(c_int) { electric = 1, benzine = 2, diesel = 3 };
const HybridC = extern struct { type1: CarC, type2: CarC };

// Zig 第一步：枚举只需要能装下 1..3 的 tag
const Car = enum(u2) { electric = 1, benzine = 2, diesel = 3 };
const Hybrid = struct { type1: Car, type2: Car };

// 第 3 步  C: 位标志 ELECTRIC=1, BENZINE=1<<1, DIESEL=1<<2; int types = ELECTRIC|BENZINE;
const ELECTRIC: c_uint = 1;
const BENZINE: c_uint = 1 << 1;
const DIESEL: c_uint = 1 << 2;

// 第 4 步  C: struct { uint8_t electric:1; uint8_t benzine:1; uint8_t diesel:1; }
const Fuel = packed struct(u8) {
    electric: bool,
    benzine: bool,
    diesel: bool,
    _pad: u5 = 0,
};

// 同样的语义用 EnumSet：按枚举字段数量自动选位宽
const FuelKind = enum { electric, benzine, diesel };

/// 再进一步：大量车辆时每辆只要 3 bit（0.17 已删除 std.PackedIntArray，这里用 std.mem.readPackedInt/writePackedInt 手写一个）
fn PackedArray(comptime T: type, comptime n: usize) type {
    return struct {
        bytes: [(n * @bitSizeOf(T) + 7) / 8]u8 = @splat(0),
        fn set(self: *@This(), i: usize, v: T) void {
            std.mem.writePackedInt(T, &self.bytes, i * @bitSizeOf(T), v, .little);
        }
        fn get(self: *const @This(), i: usize) T {
            return std.mem.readPackedInt(T, &self.bytes, i * @bitSizeOf(T), .little);
        }
    };
}

test "car case study" {
    // 2 个 int：8 字节 = 64 bit
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(HybridC));
    // Zig 小 tag：2 字节（每个 enum(u2) 存储时仍占 1 字节）
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Hybrid));
    try std.testing.expectEqual(@as(usize, 2), @bitSizeOf(Car));

    // 位标志：一个 int 4 字节
    const types: c_uint = ELECTRIC | BENZINE;
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(@TypeOf(types)));
    try std.testing.expect(types & DIESEL == 0);

    // packed struct：1 字节，有效位 8（其中 3 位有意义）
    const f: Fuel = .{ .electric = true, .benzine = true, .diesel = false };
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(Fuel));
    try std.testing.expectEqual(@as(usize, 8), @bitSizeOf(Fuel));
    const wire: u8 = @bitCast(f); // 序列化：直接拿后备整数
    try std.testing.expectEqual(@as(u8, 0b011), wire); // 与 C 的 ELECTRIC|BENZINE 数值一致
    try std.testing.expectEqual(f, @as(Fuel, @bitCast(wire)));

    var set: std.EnumSet(FuelKind) = .empty;
    set.insert(.electric);
    set.insert(.benzine);
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(std.EnumSet(FuelKind)));
    try std.testing.expect(!set.contains(.diesel));

    // 1000 辆车 × 3 bit = 3000 bit = 375 字节；对比 [1000]Fuel = 1000 字节，[1000]HybridC = 8000 字节
    var cars: PackedArray(u3, 1000) = .{};
    try std.testing.expectEqual(@as(usize, 375), @sizeOf(@TypeOf(cars)));
    cars.set(999, @truncate(wire));
    try std.testing.expectEqual(@as(u3, 0b011), cars.get(999));
    try std.testing.expectEqual(@as(usize, 1000), @sizeOf([1000]Fuel));
    try std.testing.expectEqual(@as(usize, 8000), @sizeOf([1000]HybridC));
}
```

几点补充：

- **算一下比例**：从 64 bit 降到 8 bit，是"**缩小到 1/8**"，也就是**省了 87.5%**（而不是"省了百分之八百"——节省比例不可能超过 100%）。如果再进一步按 3 bit 紧密排列，是 64 → 3 bit，约省 95%。
- **为什么 Zig 版更可靠**：C 标准把位域的位序、是否跨存储单元、`int` 位域的符号性都留给实现决定，跨编译器/跨平台序列化位域结构体是常见坑；Zig 的 `packed struct(u8)` 明确规定第一个字段在最低位，并且可以直接 `@bitCast` 成 `u8` 写到网络/文件里。
- **什么时候值得**：和视频里说的一样，UI/前端（比如 Qt 界面里的几个对象）里这点内存完全无所谓；但在内核、驱动、嵌入式、网络协议头、以及"同一个结构体有几百万个实例"的数据密集程序里，这类压缩直接决定 cache 命中率和内存峰值。
- **代价**：packed 字段的读写需要移位和掩码；`readPackedInt` 这种非字节对齐的数组访问更慢。先确认这块数据真的是瓶颈。

---

## 5. 运算篇

### 5.1 comptime：把计算挪到编译期

- **查找表**：用 `comptime` 块生成，表直接进只读数据段，运行时零初始化成本。循环次数多时用 `@setEvalBranchQuota` 提高编译期分支配额。
- **泛型特化**：`comptime N: usize` 参数让每个 N 生成一份专用代码；`inline for` 在编译期完全展开。
- 编译期断言常量之间的关系（TigerStyle 强烈推荐）：`comptime std.debug.assert(...)`。

> 📄 `examples/p01_comptime_lut.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 编译期生成查找表：CRC32（多项式 0xEDB88320）256 项，运行时零初始化成本。
const crc_table: [256]u32 = blk: {
    @setEvalBranchQuota(256 * 8 * 4);
    var t: [256]u32 = undefined;
    for (&t, 0..) |*e, i| {
        var c: u32 = @intCast(i);
        for (0..8) |_| c = if (c & 1 != 0) 0xEDB88320 ^ (c >> 1) else c >> 1;
        e.* = c;
    }
    break :blk t;
};

fn crc32(data: []const u8) u32 {
    var c: u32 = 0xFFFFFFFF;
    for (data) |b| c = crc_table[(c ^ b) & 0xFF] ^ (c >> 8);
    return ~c;
}

/// comptime 参数做泛型特化：每个 N 生成一份完全展开的代码
fn dot(comptime N: usize, a: [N]f32, b: [N]f32) f32 {
    var s: f32 = 0;
    inline for (0..N) |i| s += a[i] * b[i];
    return s;
}

test "comptime LUT" {
    try std.testing.expectEqual(std.hash.Crc32.hash("hello"), crc32("hello"));
    try std.testing.expectEqual(@as(f32, 11), dot(2, .{ 1, 2 }, .{ 3, 4 }));
}
```

**不适用**：大表会撑大二进制、拖慢编译；表比 L1/L2 cache 还大时，查表可能比现算更慢。

### 5.2 SIMD：`@Vector`

- `@Vector(N, T)` 支持逐元素算术、比较（结果是 `@Vector(N, bool)`）、`@reduce`、`@shuffle`、`@select`、`@splat`。
- 数组和向量之间可以直接强制转换（`const v: V = arr[i..][0..N].*;`）；0.16 起**禁止运行时向量下标**，要逐个访问先转成数组。
- `std.simd.suggestVectorLength(T)` 按目标 CPU 给出推荐的 lane 数（编译期常量）。
- **0.16 / 0.17 关闭了 LLVM 循环自动向量化**（规避 LLVM 的 miscompile，预计 0.18 升级 LLVM 23 后恢复）。这意味着以前"写个普通 for 循环，ReleaseFast 自动向量化"的代码现在可能慢了——热循环请显式写 `@Vector`。
- 标准库里的 `std.mem.findScalar`（原 `indexOfScalar`）等已经是向量化实现，先用标准库。

#### 先 `std.mem.findScalar` / `eql`，再手写字节循环

`findScalarPos`（`lib/std/mem.zig` 约 L1309–1370 @ `8f0c6ce4`）用展开的 2×`@Vector` 块、`@reduce(.Or)`、`simd.firstTrue`，再缩短块长，最后标量收尾。车道宽来自 `std.simd.suggestVectorLength`。在关闭自动向量化后，手写 `for`+`==` 扫 `[]u8` 很少能赢。

对有唯一表示的类型，`eql` 走 `eqlBytes`（约 L839+）：长度/`ptr` 快路径、≤16 字节 XOR 角点，再按向量（或 `usize`）分块并重叠处理最后一块。字节与 POD 比较优先 `std.mem.eql`。

**证据（语料 / U）：** `mem.zig` `findScalarPos`、`eql`/`eqlBytes`；尚无 findScalar vs 朴素循环的本地 JSONL（见 `zig-lang-perf-patterns.md`）。**证据（本地，相关）：** p16 测的是显式 `@Vector` 求和 vs 标量，不是 findScalar 对打。

> 📄 `examples/p02_simd.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const lanes = std.simd.suggestVectorLength(f32) orelse 4;
const V = @Vector(lanes, f32);

/// 显式 SIMD 求和。注意 0.16/0.17 因 LLVM bug 关闭了循环自动向量化，手写 @Vector 更重要了。
fn sum(xs: []const f32) f32 {
    var acc: V = @splat(0);
    var i: usize = 0;
    while (i + lanes <= xs.len) : (i += lanes) {
        const v: V = xs[i..][0..lanes].*; // 数组 -> 向量 强制转换
        acc += v;
    }
    var s = @reduce(.Add, acc);
    while (i < xs.len) : (i += 1) s += xs[i]; // 尾部标量处理
    return s;
}

/// 字节查找：比较得到 bool 向量 -> 位掩码 -> @ctz 找第一个命中
fn findByte(hay: []const u8, needle: u8) ?usize {
    const n = 16;
    const B = @Vector(n, u8);
    const nv: B = @splat(needle);
    var i: usize = 0;
    while (i + n <= hay.len) : (i += n) {
        const chunk: B = hay[i..][0..n].*;
        const mask: u16 = @bitCast(chunk == nv);
        if (mask != 0) return i + @ctz(mask);
    }
    while (i < hay.len) : (i += 1) if (hay[i] == needle) return i;
    return null;
}

test "simd" {
    var xs: [37]f32 = undefined;
    for (&xs, 0..) |*x, i| x.* = @floatFromInt(i);
    try std.testing.expectEqual(@as(f32, 666), sum(&xs));
    try std.testing.expectEqual(@as(?usize, 20), findByte("aaaaaaaaaaaaaaaaaaaaXaaa", 'X'));
    try std.testing.expectEqual(@as(?usize, 20), std.mem.findScalar(u8, "aaaaaaaaaaaaaaaaaaaaXaaa", 'X')); // std 已向量化
}

test "@shuffle / @select" {
    const a: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    const b: @Vector(4, i32) = .{ 10, 20, 30, 40 };
    const rev = @shuffle(i32, a, undefined, @Vector(4, i32){ 3, 2, 1, 0 });
    try std.testing.expectEqual(@Vector(4, i32){ 4, 3, 2, 1 }, rev);
    const mx = @select(i32, a > @as(@Vector(4, i32), @splat(2)), a, b); // 无分支逐 lane 选择
    try std.testing.expectEqual(@Vector(4, i32){ 10, 20, 3, 4 }, mx);
}
```

**证据（本地）：** `examples/p16_simd_vs_scalar.zig` — 标量 `f32` 求和 vs 显式 `@Vector(suggestVectorLength(f32), f32)` + `@reduce(.Add)`（N=8e6，4 遍，best-of-7，`-O fast`）。0.17 仍关闭自动向量化，标量路径不会被 LLVM 向量化。JSONL：`zig-perf-research/bench-results/p16_simd_vs_scalar.jsonl`（引用前请重跑）。

**分发问题**：`@Vector` 的宽度和指令集在编译期确定。用 `-Dcpu=native` 构建的程序在老 CPU 上会崩，用 baseline 构建又用不上 AVX2/AVX-512。Ghostty 和 Bun 因此在最热的路径上改用 Google Highway（C++，运行时按 CPUID 分发）；Bun 的 PR 说明里给出的结果是"带内联 sourcemap 的 JS 文件解析提升约 40%"。纯 Zig 方案有社区库 `oma`（把热函数按 x86-64-v2/v3/v4 等级别各编译一份，启动时选择）；语言层面的函数多版本提案是 [#1018](https://github.com/ziglang/zig/issues/1018)。

#### comptime 按 CPU 特性选型（AES 模板）

若**每个二进制**只需一条 ISA 路径，用 `builtin.cpu.has` 在 comptime 闸门并 `@import` 对应模块——零运行时 ifunc。`lib/std/crypto/aes.zig` 据此选 aesni / armcrypto / soft，并暴露 `has_hardware_support`。与 Highway 式运行时分发互补：crypto 与总是启用的 SIMD 助手用 comptime；一份构建要覆盖多代 CPU 时再用运行时多版本。

**证据（语料 / U）：** `crypto/aes.zig` L1–30。此处无 AES GB/s 表。

来源：[0.16 Loop Vectorization Disabled / Forbid Runtime Vector Indexes](https://ziglang.org/download/0.16.0/release-notes.html) · [0.17 Loop Vectorization](https://ziglang.org/download/0.17.0/release-notes.html) · [Bun PR #19134](https://github.com/oven-sh/bun/pull/19134) · [mitchellh 关于 Ghostty 使用 Highway 的说明](https://whnex.com/items/49012420) · [oma](https://github.com/ATTron/oma) · `lib/std/simd.zig` · `lib/std/mem.zig` · `lib/std/crypto/aes.zig`

### 5.3 无分支（branchless）

数据不可预测时（比如随机数据上的比较），分支预测失败的代价远高于多做几条算术指令。常用写法：`@intFromBool(cond)` 计数、`@min`/`@max`/`@abs`（通常编译为 cmov 或 min/max 指令）、`@select` 做向量化选择。

> 📄 `examples/p03_branchless.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 不可预测的数据上，用算术/选择代替分支
fn countLess(xs: []const u32, pivot: u32) usize {
    var n: usize = 0;
    for (xs) |x| n += @intFromBool(x < pivot); // 无分支计数
    return n;
}

fn clampAll(xs: []i32, lo: i32, hi: i32) void {
    for (xs) |*x| x.* = @min(@max(x.*, lo), hi); // 通常编译为 cmov / min/max 指令
}

fn absBranchless(x: i32) u32 {
    const m = x >> 31; // 算术右移得到全 0 或全 1
    return @bitCast((x ^ m) -% m);
}

test "branchless" {
    try std.testing.expectEqual(@as(usize, 2), countLess(&.{ 5, 1, 9, 3 }, 4));
    var a = [_]i32{ -5, 3, 99 };
    clampAll(&a, 0, 10);
    try std.testing.expectEqualSlices(i32, &.{ 0, 3, 10 }, &a);
    try std.testing.expectEqual(@as(u32, 7), absBranchless(-7));
    try std.testing.expectEqual(@as(u32, 7), @abs(@as(i32, -7))); // 内建 @abs 更清晰
}
```

**不适用**：分支高度可预测时（比如 99% 走同一边），普通 `if` 往往更快；无分支版本会把两边都算一遍。需要告诉编译器"这里难预测"时可以用 `@branchHint(.unpredictable)`。

### 5.4 labeled switch：解释器/状态机的分发

0.14 起 `continue :label next_value` 可以跳回 labeled switch。每个 `continue` 成为独立分支点（类似 computed goto / threaded code），便于分支预测区分来源状态；操作数编译期已知时可变成无条件跳转。Zig tokenizer 采用后官方称提速 13%。

> 📄 `examples/p04_labeled_switch.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Op = enum(u8) { push, add, mul, halt };

/// 0.14+ labeled switch：每个 continue 是独立的间接跳转点，利于分支预测（tokenizer 因此快了 13%）
/// 前置条件：code 是合法字节码（栈深不超过 16、以 halt 结尾）。
/// assert 在 Debug 下检查，ReleaseFast 下成为优化假设。
fn run(code: []const u8) i64 {
    var stack: [16]i64 = undefined;
    var sp: usize = 0;
    var pc: usize = 0;
    loop: switch (@as(Op, @fromBackingInt(code[pc]))) {
        .push => {
            std.debug.assert(sp < stack.len);
            stack[sp] = code[pc + 1];
            sp += 1;
            pc += 2;
            continue :loop @fromBackingInt(code[pc]);
        },
        .add => {
            std.debug.assert(sp >= 2);
            sp -= 1;
            stack[sp - 1] += stack[sp]; // zbc-disable-line: index-minus-one-without-zero-guard
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .mul => {
            std.debug.assert(sp >= 2);
            sp -= 1;
            stack[sp - 1] *= stack[sp]; // zbc-disable-line: index-minus-one-without-zero-guard
            pc += 1;
            continue :loop @fromBackingInt(code[pc]);
        },
        .halt => {
            std.debug.assert(sp >= 1);
            return stack[sp - 1]; // zbc-disable-line: index-minus-one-without-zero-guard
        },
    }
}

test "labeled switch interpreter" {
    const P = @backingInt(Op.push);
    const code = [_]u8{ P, 2, P, 3, @backingInt(Op.add), P, 4, @backingInt(Op.mul), @backingInt(Op.halt) };
    try std.testing.expectEqual(@as(i64, 20), run(&code));
}
```

来源：[0.14 Labeled Switch](https://ziglang.org/download/0.14.0/release-notes.html#Labeled-Switch)

**证据（本地）：** `examples/p18_labeled_switch.zig` — 小栈 VM（push/add，200k 次 add × 4 遍，best-of-7，`-O fast`）：`while`+`switch` vs labeled `continue :loop` vs 函数指针操作码表。本机两种 switch 在噪声内（~1.2 ns/dispatch）；函数指针表约 **5×** 更慢。仅作数量级 **L**；上游“tokenizer +13%”为 **U**（此处未复测）。JSONL：`zig-perf-research/bench-results/p18_labeled_switch.jsonl`。

**语料佐证：** `lib/std/zig/tokenizer.zig` 的 `next` 使用 labeled `state: switch` + `continue :state`；关键字走 `StaticStringMap`。“+13%”为 **U**（0.14 发行说明），本机未复测（见 p18）。

来源：[0.14 labeled switches](https://ziglang.org/download/0.14.0/release-notes.html#Labeled-Switch) · `lib/std/zig/tokenizer.zig`

### 5.5 分支提示与预取

- `@branchHint(.likely | .unlikely | .cold | .unpredictable | .none)` 必须是块（或函数体）的**第一条语句**；放在函数开头表示整个函数冷/热。`.cold` 允许优化器把代码放到别的内存页。
- `@prefetch(ptr, .{ .rw, .locality, .cache })`：不改变语义，只影响性能；指针无效也不是非法行为。TigerStyle 建议**显式写出全部选项**，不依赖默认值。
- `unreachable` 和 `std.debug.assert` 在 ReleaseFast 下成为优化假设（违反即 UB）。

> 📄 `examples/p05_hints.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

fn parseDigit(c: u8) !u4 {
    if (c < '0' or c > '9') {
        @branchHint(.cold); // 0.14+ 替代 @setCold；必须是块内第一条语句
        return error.InvalidDigit;
    }
    return @intCast(c - '0');
}

fn reportError(msg: []const u8) void {
    @branchHint(.cold); // 放在函数开头：整函数冷，调用点的分支也会被视为不太可能
    std.log.err("{s}", .{msg});
}

fn sumWithPrefetch(xs: []const u64) u64 {
    var s: u64 = 0;
    for (xs, 0..) |x, i| {
        if (i + 64 < xs.len) {
            // TigerStyle 建议显式写出所有选项，避免默认值变化
            @prefetch(&xs[i + 64], .{ .rw = .read, .locality = 3, .cache = .data });
        }
        s +%= x;
    }
    return s;
}

test "hints" {
    try std.testing.expectEqual(@as(u4, 7), try parseDigit('7'));
    try std.testing.expectError(error.InvalidDigit, parseDigit('x'));
    var xs: [200]u64 = undefined;
    for (&xs, 0..) |*x, i| x.* = i;
    try std.testing.expectEqual(@as(u64, 19900), sumWithPrefetch(&xs));
    _ = &reportError;
}
```

**不适用**：手动预取在硬件预取器已经能识别的顺序访问上通常没收益，甚至有害；只在指针追逐、间接下标等不规则访问上尝试，并实测。

来源：[0.14 @branchHint](https://ziglang.org/download/0.14.0/release-notes.html#New-branchHint-Builtin-Replacing-setCold) · [语言参考 @prefetch](https://ziglang.org/documentation/0.17.0/#prefetch)

### 5.6 循环形状、内联、传参

- **热循环抽成独立函数，只接受原始参数，不带 `self`**（TigerStyle）：编译器不需要证明 `self.field` 没被别名修改，就能把它放进寄存器；读者也更容易看出冗余计算。
- **多路累加器 / 循环展开**：`inline for` 生成固定数量的独立累加器，打破加法依赖链。展开会增大代码，i-cache 压力是真实成本。
- **`inline fn` 不是提示**：语言参考明确说它是"语义上的内联"，编译期已知的实参在被调函数内也视为编译期参数；代价是可能伤害二进制大小、编译速度，甚至运行时性能。一般让编译器自己决定，只在需要编译期传播或确保栈帧形态时才用。
- **大结构体按 `*const T` 传**（TigerStyle：>16 字节且无意拷贝时），以及"push ifs up, fors down"——把分支提到循环外，把循环下推到批处理函数里。
- 大结构体**原地初始化**：`fn init(self: *Big) void { self.* = .{...}; }`，避免先在栈上构造再拷贝（TigerStyle）。

> 📄 `examples/p09_hot_loop.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

const Mesh = struct {
    xs: []f32,
    scale: f32,

    /// 反模式：热循环里反复经过 self 指针访问字段，编译器要证明无别名才能缓存
    fn scaleSlow(self: *Mesh) void {
        for (self.xs) |*x| x.* *= self.scale;
    }
    /// TigerStyle：把热循环抽成只接收原始参数的独立函数
    fn scaleFast(self: *Mesh) void {
        scaleKernel(self.xs, self.scale);
    }
};

fn scaleKernel(xs: []f32, scale: f32) void {
    for (xs) |*x| x.* *= scale;
}

/// 循环展开：inline for 生成固定 4 路累加器，打破依赖链
fn sum4(xs: []const u64) u64 {
    var acc: [4]u64 = @splat(0);
    var i: usize = 0;
    while (i + 4 <= xs.len) : (i += 4) {
        inline for (0..4) |k| acc[k] +%= xs[i + k];
    }
    var s = acc[0] +% acc[1] +% acc[2] +% acc[3];
    for (xs[i..]) |x| s +%= x;
    return s;
}

/// 大结构体按 *const 传，避免意外拷贝（TigerStyle：>16 字节时）
const Big = struct { data: [256]u8 };
fn checksum(b: *const Big) u32 {
    var s: u32 = 0;
    for (b.data) |x| s +%= x;
    return s;
}

/// inline fn：强制在调用点内联（语义上的保证，不是提示）
inline fn sq(x: f32) f32 {
    return x * x;
}

test "hot loops" {
    var data = [_]f32{ 1, 2, 3 };
    var m: Mesh = .{ .xs = &data, .scale = 2 };
    m.scaleSlow();
    m.scaleFast();
    try std.testing.expectEqual(@as(f32, 12), data[2]);
    try std.testing.expectEqual(@as(u64, 15), sum4(&.{ 1, 2, 3, 4, 5 }));
    const big: Big = .{ .data = @splat(1) };
    try std.testing.expectEqual(@as(u32, 256), checksum(&big));
    try std.testing.expectEqual(@as(f32, 9), sq(3));
}
```

来源：[TigerStyle: Performance / Cache Invalidation](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#performance) · [matklad: Push Ifs Up And Fors Down](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html) · [语言参考 inline fn](https://ziglang.org/documentation/0.17.0/#inline-fn)

### 5.7 局部关闭安全检查、浮点模式

- `@setRuntimeSafety(false)` 作用于**调用所在的作用域**，可以在任意内层作用域再覆盖回来。在 ReleaseSafe 下用它关闭已验证热点的越界/溢出检查；在 ReleaseFast 下本来就是关的。**范围越小越好**（zperf-lint zp-broad-runtime-safety 会报告覆盖整个大函数体的情况）。
- `@setFloatMode(.optimized)`：允许假设没有 NaN/Inf、忽略零的符号、用倒数代替除法、做浮点收缩（如 FMA）——相当于 `-ffast-math`。结果可能与严格 IEEE 有细微差异。
- `@mulAdd(T, a, b, c)` 显式 FMA。

> 📄 `examples/p07_safety.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 只在已验证的热点里局部关闭安全检查，不要放在文件作用域
fn sumUnchecked(xs: []const u32) u32 {
    @setRuntimeSafety(false); // 本作用域内去掉越界/溢出检查（在 ReleaseSafe/Debug 下生效）
    var s: u32 = 0;
    for (xs) |x| s += x; // 溢出将变成 UB 而不是 panic —— 前提是你已经证明不会溢出
    return s;
}

fn dotFast(a: []const f32, b: []const f32) f32 {
    @setFloatMode(.optimized); // 允许重结合/FMA 收缩等（-ffast-math 语义），结果可能有微小差异
    std.debug.assert(a.len == b.len); // Release 下 assert 变成优化假设
    var s: f32 = 0;
    for (a, b) |x, y| s += x * y;
    return s;
}

test "safety toggles" {
    try std.testing.expectEqual(@as(u32, 6), sumUnchecked(&.{ 1, 2, 3 }));
    try std.testing.expectApproxEqAbs(@as(f32, 11), dotFast(&.{ 1, 2 }, &.{ 3, 4 }), 1e-6);
    try std.testing.expectEqual(@as(f32, 7), @mulAdd(f32, 2, 3, 1)); // 显式 FMA
}
```

**不适用**：没有测试覆盖、没有被 fuzz 过的代码不要关安全检查——在 Zig 里这会把 bug 变成未定义行为。

来源：[语言参考 @setRuntimeSafety / @setFloatMode](https://ziglang.org/documentation/0.17.0/#setRuntimeSafety)

### 5.8 整数技巧

- **避免运行时整数除法**：除数是编译期常量时 LLVM 会改写成乘法+移位；除以运行时变量才是真正的除法指令。容量取 2 的幂，`% cap` 变成 `& (cap - 1)`。
- 回绕运算 `+%`、`-%`、`*%`；饱和运算 `+|`、`-|`、`*|`；显式溢出 `@addWithOverflow`/`@mulWithOverflow`。
- 位操作内建：`@popCount`、`@clz`、`@ctz`、`@byteSwap`、`@bitReverse`；0.17 新增 `@divCeil`（以后不必写 `std.math.divCeil(...) catch unreachable`）。
- TigerStyle 还建议用 `@divExact` / `@divFloor` / `divCeil` 表明你考虑过取整方向。

> 📄 `examples/p08_int_tricks.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 容量取 2 的幂：取模变成按位与
const Ring = struct {
    const cap = 1024;
    comptime {
        std.debug.assert(std.math.isPowerOfTwo(cap));
    }
    buf: [cap]u32 = undefined,
    head: u32 = 0, // 允许自然回绕

    fn push(r: *Ring, v: u32) void {
        r.buf[r.head & (cap - 1)] = v; // 等价于 % cap，但不需要除法
        r.head +%= 1; // wrapping 加法：明确表示可回绕，没有溢出检查
    }
};

test "整数技巧" {
    var r: Ring = .{};
    for (0..2000) |i| r.push(@intCast(i));
    try std.testing.expectEqual(@as(u32, 1999), r.buf[1999 & 1023]);

    // 除以编译期常量：LLVM 会改写成乘法+移位；除以运行时变量才是真·除法指令
    const x: u32 = 1000;
    try std.testing.expectEqual(@as(u32, 142), x / 7);
    try std.testing.expectEqual(@as(u32, 3), @divCeil(@as(u32, 7), 3)); // 0.17 新增
    try std.testing.expectEqual(@as(u32, 125), x >> 3);

    const r2 = @mulWithOverflow(@as(u8, 200), 2); // 显式拿到溢出位
    try std.testing.expectEqual(@as(u1, 1), r2[1]);
    try std.testing.expectEqual(@as(u8, 255), @as(u8, 200) +| 100); // 饱和加法
    try std.testing.expectEqual(@as(u32, 3), @popCount(@as(u32, 0b1011)));
    try std.testing.expectEqual(@as(u32, 28), @clz(@as(u32, 0b1011)));
    try std.testing.expectEqual(@as(u64, 0x0807060504030201), @byteSwap(@as(u64, 0x0102030405060708)));
    try std.testing.expectEqual(@as(u32, 16), try std.math.ceilPowerOfTwo(u32, 9));
}
```

### 5.9 `@memcpy` / `@memset` 与标准库的向量化例程

`@memcpy(dest, src)`、`@memset(slice, value)` 会降级为优化过的 memcpy/memset（0.14 compiler_rt 里有优化过的 memcpy）；`@memcpy` 要求源和目标不重叠、长度相等（Debug/Safe 下有检查），重叠时用 `@memmove`。`std.mem.findScalar`、`std.mem.eql` 等已经针对向量做过优化，优先使用而不是手写字节循环——结构见 §5.2 的 `findScalarPos` / `eqlBytes`。

子串查找：`std.mem.find` 用带跳表的 Boyer–Moore–Horspool（`mem.zig`），不是朴素 O(nm)。多字节 needle 优先用它。

### 5.10 排序：优先 `std.sort.pdq`

std 默认质量排序是 **pdqsort**（`std.sort.pdq` / `lib/std/sort/pdq.zig`）。`std.sort.block` 在其文档约束下可用；极小 n 有插入类助手。没有实测理由就别在业务里重写 quicksort。

**证据（语料 / U）：** `lib/std/sort.zig` 导出；本仓库无排序对打。

---

## 6. 并发与 I/O

### 6.1 False sharing 与缓存行对齐

两个线程频繁写的变量落在同一条 cache line 上，会导致这条线在核心之间来回失效。用 `align(std.atomic.cache_line)` 把每个线程的数据隔开（`std.atomic.cache_line` 是按目标 CPU 计算的编译期常量）。

`std.heap.smp_allocator` 已对每线程 freelist 槽做 `align(std.atomic.cache_line)`（§2.1）。你自己的热原子变量仍要同样处理——堆的垫片帮不了你的计数器。

> 📄 `examples/p06_false_sharing.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 每线程计数器各占一条缓存行，避免 false sharing
const PaddedCounter = struct {
    value: std.atomic.Value(u64) align(std.atomic.cache_line) = .init(0),
};

fn worker(c: *PaddedCounter, n: usize) void {
    for (0..n) |_| _ = c.value.fetchAdd(1, .monotonic);
}

test "false sharing" {
    try std.testing.expect(@sizeOf(PaddedCounter) >= std.atomic.cache_line);
    var counters: [4]PaddedCounter = @splat(.{});
    var threads: [4]std.Thread = undefined;
    for (&threads, &counters) |*t, *c| t.* = try std.Thread.spawn(.{}, worker, .{ c, 10_000 });
    for (threads) |t| t.join();
    var total: u64 = 0;
    for (&counters) |*c| total += c.value.load(.monotonic);
    try std.testing.expectEqual(@as(u64, 40_000), total);
}
```

**证据（本地）：** `examples/p17_false_sharing.zig` — 相邻 `Atomic(u64)` 计数器 vs `align(std.atomic.cache_line)` 填充计数器（2/4/8 线程 × 各 2e6 次 `fetchAdd(.monotonic)`，best-of-5，`-O fast`）。JSONL：`zig-perf-research/bench-results/p17_false_sharing.jsonl`。

### 6.2 任务并行：`Io.Group`（0.16 起取代 `Thread.Pool`）

0.16 删除了 `std.Thread.Pool`。官方迁移建议：`spawnWg` → `Io.Group.async`；需要真正并发（而不只是"可以异步"）时用 `io.concurrent`，它可能返回 `error.ConcurrencyUnavailable`。切换到 `Io` 之后，`Thread.Mutex` 等同步原语也要换成 `Io.Mutex`、`Io.Condition`、`Io.Event`。Group 适合"大量同寿命任务"，派生 N 个任务的开销是 O(1)。

> 📄 `examples/p11_group.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");
const Io = std.Io;

/// 0.16 移除了 std.Thread.Pool，并行任务改用 Io.Group / io.async
fn sumChunk(xs: []const u64, out: *u64) void {
    var s: u64 = 0;
    for (xs) |x| s +%= x;
    out.* = s;
}

fn parallelSum(io: Io, xs: []const u64) !u64 {
    const chunks = 4;
    var partial: [chunks]u64 = @splat(0); // 每个任务写自己的槽，无共享写
    const step = (xs.len + chunks - 1) / chunks;
    var g: Io.Group = .init;
    errdefer g.cancel(io);
    for (0..chunks) |c| {
        const lo = @min(c * step, xs.len);
        const hi = @min(lo + step, xs.len);
        g.async(io, sumChunk, .{ xs[lo..hi], &partial[c] });
    }
    try g.await(io);
    var s: u64 = 0;
    for (partial) |p| s +%= p;
    return s;
}

test "Io.Group" {
    var xs: [1000]u64 = undefined;
    for (&xs, 0..) |*x, i| x.* = i;
    try std.testing.expectEqual(@as(u64, 499500), try parallelSum(std.testing.io, &xs));
}
```

**避免共享写**：每个任务写自己的槽位，最后归并；比原子计数器或锁快得多。

### 6.3 I/O 缓冲：新的 `Io.Writer`（Writergate）

0.15 起由调用方提供 Writer 缓冲；升级指南原话："Please use buffering! And don't forget to flush!"。接口还支持 splat（重复字节不物化）、`sendFile`（fd 到 fd）、vectored 写——沿 I/O 栈传递可减少系统调用与内存流量。

**Drain / splat / Allocating（语料）。** `Io.Writer.writeSplat` / `writeSplatHeader`（`lib/std/Io/Writer.zig` 约 L181+）把末尾重复切片合并写出，不必物化大临时缓冲。具体 Writer 实现 `drain`，冲刷缓冲与带 splat 计数的向量尾。`Writer.Allocating` 在 ArrayList 式缓冲上增长，flush 基本是空操作直到你取走字节——适合“格式化进内存”，少一套 `ArrayList`+formatter（`Allocating` 约 L2644+）。`.buffer = &.{}` 仍是无缓冲（每次写都可能立刻 `drain`）。

> 📄 `examples/p10_io_writer.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");

/// 0.15 Writergate 之后：缓冲区在接口内，用户提供 buffer；记得 flush！
fn writeReport(w: *std.Io.Writer, rows: []const u32) !void {
    for (rows, 0..) |r, i| try w.print("{d}: {d}\n", .{ i, r });
    try w.splatByteAll('-', 10); // splat：重复字节无需物化
    try w.writeByte('\n');
}

test "buffered writer to file" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const file = try tmp.dir.createFile(io, "out.txt", .{});
    defer file.close(io);

    var buf: [4096]u8 = undefined; // 一次 write 系统调用最多刷 4 KiB
    var fw = file.writer(io, &buf);
    try writeReport(&fw.interface, &.{ 7, 8, 9 });
    try fw.interface.flush(); // 不 flush 数据会丢
}

test "Allocating writer" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try writeReport(&aw.writer, &.{1});
    try std.testing.expectEqualStrings("0: 1\n----------\n", aw.written());
}
```

**反模式**：`file.writer(io, &.{})`（空缓冲，每次写都可能是系统调用）；热循环里 `std.debug.print`（锁 stderr，仅 64 字节缓冲，见 `lib/std/debug.zig`）。zperf-lint zp-unbuffered-io、zp-print-hot 会报。

**证据包（L = 本地，U = 上游）：**

| 主张 | 类 | 指针 |
|---|---|---|
| 空 Writer 缓冲 vs 4 KiB，小写 `/dev/null` | **L** | `examples/p19_io_buffering.zig`：空缓冲约 **150** ns/write，4 KiB 约 **3** ns/write（约 **50×**）；`strace -c -e writev` 一次：`writev` **100000** vs **390**。JSONL：`zig-perf-research/bench-results/p19_*` |
| 无缓冲文件编码远慢于内存/缓冲路径 | **U** | [zigimg#55](https://github.com/zigimg/zigimg/issues/55)：无缓冲写文件约 **5 s** vs 内存路径 **ms**；即使 `/dev/null` 约 **500 ms vs ~35 ms**（报告者机器，此处未复测） |
| 通用 / 字节循环 Reader vs 专用缓冲路径 | **U** | [zig#17985](https://github.com/ziglang/zig/issues/17985)：默认 `streamUntilDelimiter` 字节循环；专用 BufferedReader 讨论中称 **2×–15×** |
| 类型擦除 AnyWriter vs 具体 BufferedWriter | **U** | [zig#21566](https://github.com/ziglang/zig/issues/21566)：AnyWriter 毁掉内联；1 MiB 字节循环与具体 writer 的差距（issue 讨论） |
| Writer drain / splat / Allocating API 形态 | **U** | `lib/std/Io/Writer.zig` @ `8f0c6ce4`（`writeSplat`、`Allocating`）——API 证据，非计时主张 |

本地 p19 测的是 Writergate `Io.Writer` 下的 **syscall / 缓冲** 成本。上游 issue 覆盖**通用接口**与**真实文件编码**；其绝对时间是 **U**。热路径用具体缓冲 writer；空缓冲靠 zp-unbuffered-io。

**stdout/stderr 用 `writerStreaming`**：`file.writer()` 是定位（positional）模式，用 pwrite 从偏移 0 写起；当 stdout 被 shell 重定向到一个已有内容的文件（如 `{ echo a; ./app; } > log`）时，会覆盖掉前面的内容。我们在写 zperf-lint 时真的踩到了这个坑。管道、终端、共享的输出文件请用 `File.stdout().writerStreaming(io, &buf)`。

### 6.4 系统调用批处理：Batch 与 io_uring

- `Io.Batch` 在 Operation 层面把多个操作（目前包括 `FileReadStreaming`、`FileWriteStreaming`、`DeviceIoControl`、`NetReceive`）一起发出，官方建议"写最优的可复用代码时优先 Batch"，需要在操作之间插入逻辑时再用 Future。
- `Io.Uring`（基于 io_uring 的 `Io` 实现）在 0.16 还是概念验证阶段：缺网络、错误处理和测试覆盖。
- 底层的 `std.os.linux.IoUring` 可直接使用：多个 SQE 一次 `submit()` 提交。

> 📄 `examples/p13_uring.zig`（Zig 0.17.0 下 `zig test` 通过）

```zig
const std = @import("std");
const builtin = @import("builtin");

// Linux io_uring：批量提交多个 I/O，一次 syscall（submit）完成
test "io_uring nop batch" {
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;
    var ring = std.os.linux.IoUring.init(8, 0) catch return error.SkipZigTest; // 容器/老内核可能不支持
    defer ring.deinit();
    for (0..4) |i| _ = try ring.nop(@intCast(i));
    try std.testing.expectEqual(@as(u32, 4), try ring.submit()); // 4 个 SQE 一次提交
    var cqes: [4]std.os.linux.io_uring_cqe = undefined;
    const n = try ring.copy_cqes(&cqes, 4);
    try std.testing.expectEqual(@as(u32, 4), n);
}
```

来源：[0.15 Writergate](https://ziglang.org/download/0.15.1/release-notes.html#Writergate) · [0.16 I/O as an Interface / Batch / Thread.Pool Removed](https://ziglang.org/download/0.16.0/release-notes.html) · `lib/std/os/linux/IoUring.zig`

---

## 7. 构建与工具链

### 7.1 优化模式与常用开关（0.17 名称）

| 目的 | 命令行（`zig build-exe`） | `build.zig` | 说明 |
|---|---|---|---|
| 最快 | `-O fast` | `-Doptimize=fast` | 关闭安全检查。0.17 起 tag 名为 `debug/safe/fast/small`（旧名 `ReleaseFast` 等已改） |
| 带检查的发布版 | `-O safe` | `-Doptimize=safe` | 生产环境默认推荐；热点处局部 `@setRuntimeSafety(false)` |
| 最小体积 | `-O small` | `-Doptimize=small` | |
| 目标 CPU | `-mcpu native` / `-mcpu x86_64_v3` | `-Dcpu=native` | 发布给别人的二进制不要用 native，见 5.2 |
| LTO | `-flto` / `-fno-lto` | `exe.lto = .full`（`std.zig.LtoMode`: `none/full/thin`） | 需要 LLVM 后端 |
| 去符号 | `-fstrip` | `.strip = true`（Module 选项） | |
| 单线程 | `-fsingle-threaded` | `.single_threaded = true` | 原子操作、锁降级；`smp_allocator` 不可用 |
| 去 unwind 表 | `-fno-unwind-tables` | `.unwind_tables = .none` | 减体积，影响栈回溯 |
| 帧指针 | `-fomit-frame-pointer` | `.omit_frame_pointer = true` | 想用 perf 看调用栈时反而要保留 |
| 栈诊断 | `-fstack-report` | | 每个函数的栈大小 |
| libc | `-lc` | `.link_libc = true` | 链接后 `init.gpa` 在 Fast 下变为 `c_allocator` |

一个可编译的 `build.zig`（`examples/build_example/`，`zig build -Doptimize=fast` 实测通过）：

> 📄 `examples/build_example/build.zig`（Zig 0.17.0 下 `zig build -Doptimize=fast` 通过）

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{}); // -Dtarget=... -Dcpu=native
    const optimize = b.standardOptimizeOption(.{}); // -Doptimize=ReleaseFast 等
    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize != .debug, // 去符号，减小体积
            .single_threaded = false, // 确认无多线程时设 true：原子/锁降级为普通操作
            .unwind_tables = .none, // 体积敏感时去掉 unwind 表（会影响栈回溯）
            .omit_frame_pointer = true,
        }),
    });
    exe.lto = .full; // LTO（需要 LLVM 后端；0.17 字段名为 lto: ?LtoMode）
    b.installArtifact(exe);
}
```

本机实测（x86_64 Linux，只作为量级参考；程序是 `examples/build_example/main.zig`，一个只分配并清零 1000 个 u64 的小程序）：同一程序在上面的配置下，`-Doptimize=fast` 产物 217,712 字节，`-Doptimize=small` 产物 123,696 字节。

### 7.2 二进制瘦身

- `-O small` + `-fstrip` + `-fno-unwind-tables`；确认无多线程时 `-fsingle-threaded`。
- 少用 `std.fmt` 的大量不同格式串：每个 `print` 的格式串和参数类型组合都会实例化一份格式化代码（编译期泛型）。0.16 的 "Lazy Field Analysis" 让只把 `std.Io.Writer` 当命名空间用时不再拉入整个 vtable，减少了无谓的代码生成。
- 0.16 "Improved Code Generation of For Loop Safety Checks"：遍历切片的代码量减少约 30%（官方数据）。

### 7.3 PGO

截至本文，Zig **不支持**对用户程序做 profile-guided optimization：相关请求 [#15137](https://github.com/ziglang/zig/issues/15137) 已以 "not planned" 关闭；"基于测试用例的自动 PGO" 的研究性 issue [#237](https://github.com/ziglang/zig/issues/237) 仍开着。替代办法是手动：`@branchHint`、冷热函数分离、布局调整。

来源：`zig build-exe --help`（0.17.0）· [0.17 Rename lang.OptimizeMode to lang.Optimize](https://ziglang.org/download/0.17.0/release-notes.html) · [0.16 Lazy Field Analysis / For Loop Safety Checks](https://ziglang.org/download/0.16.0/release-notes.html) · `lib/std/Build/Step/Compile.zig`

### 7.4 来自 Zig 编译器 / std 的模式（短）

写解析器、LS、打包器这类“像编译器”的工具时有用。完整笔记：`zig-perf-research/zig-lang-perf-patterns.md`（语料 `zig-corpus/zig` @ `8f0c6ce4`）。

| 模式 | 位置 | 带走什么 |
|---|---|---|
| 按经验 `ensureTotalCapacity` | `lib/std/zig/Ast.zig` | 按输入比例预留（§2.6） |
| SoA + `extra` + `string_bytes` | `lib/std/zig/Zir.zig` | 密 IR；少见操作离线（§2.8） |
| 分片驻留 + tid 索引 | `src/InternPool.zig` | 并发 intern 不靠全局锁（§2.10） |
| labeled-switch tokenizer | `lib/std/zig/tokenizer.zig` | 同 §5.4；关键字 `StaticStringMap` |
| 可选 tracy 钩子 | `src/tracy.zig` | 追编译时间时可插桩（**U**） |
| 内容寻址构建缓存 | `lib/std/Build/Cache.zig` | SipHash 清单做增量产物（邻接 §8.4） |

别把编译器内部生搬进小程序。量过之后再偷**形状**（索引、SoA、分片、ensure 启发式）。

---

## 8. 度量与验证

### 8.1 微基准

0.16 起 `std.time.Timer` 已移除。计时走 `Io`：`std.Io.Clock.Timestamp.now(io, .awake)` 与 `.untilNow(io)`。用 `std.mem.doNotOptimizeAway` 防止被测工作被删掉。多跑几轮，取**最佳**（或报分布），减轻中断与冷缓存噪声。

记录 Zig 版本、优化模式、OS、CPU 型号，便于跨机对比。示例每条结果打一行 **JSONL**。

> 📄 `examples/p12_bench.zig`（Zig 0.17.0 下 `zig run -O fast` 通过）

```zig
const std = @import("std");

/// 微基准：0.16 起 std.time.Timer 已移除，计时走 Io.Clock
fn work(xs: []u64) u64 {
    var s: u64 = 0;
    for (xs) |x| s +%= x *% 2654435761;
    return s;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const xs = try gpa.alloc(u64, 1 << 20);
    defer gpa.free(xs);
    for (xs, 0..) |*x, i| x.* = i;

    var best: i96 = std.math.maxInt(i96);
    for (0..10) |_| {
        const t0: std.Io.Clock.Timestamp = .now(io, .awake);
        const r = work(xs);
        std.mem.doNotOptimizeAway(r);
        const dt = t0.untilNow(io);
        best = @min(best, dt.raw.nanoseconds);
    }
    var buf: [256]u8 = undefined;
    var w = std.Io.File.stdout().writerStreaming(io, &buf);
    try w.interface.print("best: {d} ns\n", .{best});
    try w.interface.flush();
}
```

共用字段放在 `examples/bench_jsonl.zig`（`name`、`ns_per_op`、`iters`、`zig_version`、`optimize_mode`、`os`、`cpu_model`、`note`）。对比型基准同样 `@import` 它。

**证据（本地）：** 分配器对照见 `zig-perf-research/bench-results/`（`p14_alloc_shootout`，见该目录 `README.md`）。数字因机器而异，引用前请重跑。

### 8.2 工具

- **perf：** `perf stat -e cycles,instructions,cache-misses,branch-misses ./app` 看整体；`perf record -g` + `perf report` 找热点（保留帧指针：勿默认 `-fomit-frame-pointer`，或 `.omit_frame_pointer = false`）。Zig release notes 的多指标表（墙钟、峰值 RSS、cache/branch miss）是好模板。
- **对比命令：** Andrew Kelley 的 [poop](https://github.com/andrewrk/poop) 一次跑多个命令并打印同类计数器。
- **valgrind：** `valgrind --tool=cachegrind`；需要时用 `-fvalgrind` 在 release 里保留 client request。
- **Tracy：** 帧级 profiler，社区有 Zig 绑定。
- **汇编：** `zig build-obj -O fast -femit-asm=out.s file.zig`，或 [Compiler Explorer](https://godbolt.org/) 选 Zig，确认 SIMD / 内联。
- **内存：** Debug/Safe 下 `SafeAllocator` 报泄漏；测试用 `std.testing.allocator`。`/usr/bin/time -v` 看峰值 RSS。

### 8.3 实践

1. 先估算（第 1 章），再写代码，再测量，再优化热点。
2. 一次只改一个变量；对比多次运行的分布，不要只看单次数字。
3. 优化后保留测试与断言——TigerStyle：断言把灾难性正确性 bug 降成活性问题。

### 8.4 持续 / 回归测量

一次性微基准比较本机 A vs B。持续测量问的是：上周的合并有没有把产品变慢。TigerBeetle Continuous Performance Orchestrator 草案（[PR #3737](https://github.com/tigerbeetle/tigerbeetle/pull/3737)，未合并关闭）与 ZLS 对标准 LSP 性能跟踪的诉求（[issue #1522](https://github.com/zigtools/zls/issues/1522)）方向一致：**每个提交（或 nightly）存可比的一行数据，而不是 CI 里写死一个绝对纳秒门槛。**

**每提交记录的 JSONL 字段**（与 `examples/bench_jsonl.zig` 相同）：

| 字段 | 作用 |
|---|---|
| `name` | 稳定 id（`alloc_arena_retain`、`io_write_4kib_buf`…） |
| `ns_per_op`、`iters` | 墙钟指标与规模 |
| `zig_version`、`optimize_mode` | 工具链 / 模式漂移 |
| `os`、`cpu_arch`、`cpu_model` | 跨机过滤 |
| `note` | 负载旋钮（N、缓冲、线程数） |

版本化产物里每行一个 JSON（或结果库）。Ghostty 应用内 FPS / 帧统计（[PR #14488](https://github.com/ghostty-org/ghostty/pull/14488)）与滚动路径回归守卫（[PR #1612](https://github.com/ghostty-org/ghostty/pull/1612)）对交互负载是同一思路：盯稳定信号，而不是 `assert(ns < K)`。

**可选 Linux 计数器：**

```sh
perf stat -e cycles,instructions,cache-misses,branch-misses,task-clock \
  ./zig-out/bin/your_bench
```

TigerBeetle 的 `perf_event` 包装草案（[PR #3859](https://github.com/tigerbeetle/tigerbeetle/pull/3859)，未合并）曾把 cycles / miss / IPC 导出 CSV。本仓库默认只做墙钟 JSONL；需要第二轴时再挂 `perf`。不要在指南里编造计数器数字——在认领的那台机器上重跑。

**少用绝对 ns 的 CI 断言。** 虚拟机、睿频、吵邻居、Zig 升级往往比真实回归更能挪动墙钟。优先：

1. **相对门禁**（同一 runner 上 `ns_per_op` 相对上一提交中位数涨超 N% 则失败），或
2. **趋势面板** + 人工审阅，或
3. PR CI 只做**正确性 + smoke**，重型 perf 放 nightly。

本文微基准表是 **L**（本地）。引用的上游 PR/issue 是 **U**。产品决策前请重跑。

来源：Zig 0.16/0.17 release notes（`Io`、`Clock`）· [poop](https://github.com/andrewrk/poop) · TigerStyle · `examples/p12_bench.zig` · `examples/bench_jsonl.zig` · [TB#3737](https://github.com/tigerbeetle/tigerbeetle/pull/3737) · [TB#3859](https://github.com/tigerbeetle/tigerbeetle/pull/3859) · [ZLS#1522](https://github.com/zigtools/zls/issues/1522) · [Ghostty#14488](https://github.com/ghostty-org/ghostty/pull/14488)

---

## 9. zperf-lint：自动找出反模式

`zperf-lint/` 是 Zig 0.17 静态检查器：`std.zig.Ast.parse` 解析后线性扫描 AST 节点（不递归）；用 token 区间判断是否在循环/函数内。

```sh
cd zperf-lint
zig build -Doptimize=fast          # 产物: zig-out/bin/zperf-lint
zig build test                     # 单元测试 + 夹具测试（每条规则 bad 必中、good 必不中）
./zig-out/bin/zperf-lint src/ my_file.zig --format json --disable zp-runtime-div-hot
```

规则一览（详见 `zperf-lint/README.md`，或运行 `zperf-lint --list-rules`）：

| ID | 名称 | 级别 | 检查内容 |
|---|---|---|---|
| zp-alloc-hot | `alloc-in-loop` | warning | 循环体内进行堆分配 |
| zp-append-without-reserve | `append-without-reserve` | info | for/while 循环中 append，循环前没有预留容量 |
| zp-page-allocator-small | `page-allocator-small` | warning | 直接用 page_allocator 做小块/容器分配 |
| zp-debug-allocator | `debug-allocator` | warning | 使用 GeneralPurposeAllocator/DebugAllocator，且文件中看不到按 builtin.mode 切换 |
| zp-large-struct-by-value | `large-struct-by-value` | info | 按值传递较大的结构体 |
| zp-print-hot | `print-in-loop` | warning | 循环内 `std.debug.print`；`std.log.*` 仅在 `--strict-log-in-loop` |
| zp-unbuffered-io | `unbuffered-io` | warning | 空缓冲 reader/writer；跳过测试、`readVec`/`writeVec`、一次性写等 |
| zp-missing-free | `missing-free` | warning | 分配/初始化后在函数内找不到 deinit/free/destroy 或所有权转移 |
| zp-extern-struct-padding | `extern-struct-padding` | warning | extern struct 字段顺序导致多余 padding |
| zp-broad-runtime-safety | `broad-runtime-safety` | warning | @setRuntimeSafety(false) 作用范围过大 |
| zp-packable-bools | `packable-bools` | info | 结构体含多个 bool 字段，每个占 1 字节 |
| zp-usize-index-field | `usize-index-field` | info | 索引类字段使用 usize（64 位上 8 字节） |
| zp-aos-single-field | `aos-single-field` | hint | 遍历结构体数组时只访问一个字段 |
| zp-catch-unreachable-alloc | `catch-unreachable-alloc` | warning | 对可能 OOM 的调用使用 catch unreachable |
| zp-oversized-enum-tag | `oversized-enum-tag` | info | enum 显式 tag 类型远大于所需 |
| zp-optional-scalar-field | `optional-scalar-field` | info | 结构体字段是可选标量（?u32 等），额外 flag 会被对齐放大 |
| zp-bool-array | `bool-array` | info | 用 bool 数组/切片存位标志 |
| zp-static-string-map | `static-string-map` | info | StringHashMap 只用字面量键填充 |
| zp-runtime-div-hot | `runtime-div-in-loop` | hint | 循环内除以/取模运行时变量 |
| zp-queue-ordered-remove | `queue-ordered-remove` | warning | 把 ArrayList 当队列：orderedRemove(0) / 循环内 orderedRemove |
| zp-shift-on-read | `shift-on-read` | warning | 读走前缀后把剩余数据整体搬回开头 |
| zp-per-packet-alloc | `per-packet-alloc` | info | 逐包/逐帧热路径中进行堆分配 |
| zp-invariant-float-div | `invariant-float-div` | hint | 循环内除以循环不变的浮点数 |
| zp-map-put-without-ensure | `map-put-without-ensure` | info | 循环内 HashMap `put`/`getOrPut` 且未见 `ensure*` |
| zp-catch-unreachable-io | `catch-unreachable-io` | warning | 易失败 I/O 上 `catch unreachable`（非 close/eventfd/kevent） |
| zp-arena-reset-free-all | `arena-reset-free-all` | warning | 循环内 `ArenaAllocator.reset(.free_all)` 或 arena deinit+重建；优先 retain |
| zp-create-destroy-hot | `create-destroy-in-loop` | info | 同一循环内 `create(T)` 配 `destroy`；优先 `MemoryPool(T)` |
| zp-fixed-size-alloc-hot | `fixed-size-alloc-in-loop` | info | 循环内 `alloc(u8, comptime_int)`（≥16）；优先 size-class 缓冲池 |

在夹具上运行的输出示例（节选）：

```text
$ zperf-lint fixtures/bad/zp-alloc-hot.zig fixtures/bad/zp-extern-struct-padding.zig ...
fixtures/bad/zp-alloc-hot.zig:5:34: warning[zp-alloc-hot alloc-in-loop] 循环体内进行堆分配 / heap allocation inside a loop body: gpa.alloc(...)
    建议: 把分配提到循环外并复用缓冲区；或改用 ArenaAllocator + reset(.retain_capacity) / MemoryPool
fixtures/bad/zp-extern-struct-padding.zig:1:27: warning[zp-extern-struct-padding extern-struct-padding] extern struct 字段顺序导致多余 padding / extern struct field order wastes bytes on padding: 当前 24 字节，按对齐降序重排后 16 字节
    建议: 按对齐从大到小重排字段（若 ABI 允许）；普通 struct 编译器会自动重排
fixtures/bad/zp-oversized-enum-tag.zig:1:19: info[zp-oversized-enum-tag oversized-enum-tag] enum 显式 tag 类型远大于所需 / enum explicit tag type is wider than needed: enum(u32) 只有 3 个值，u8 即可（不写 tag 时编译器自动选最小宽度）
    建议: 去掉显式 tag 让编译器推断最小宽度，或用 enum(u8)；仅在 ABI/协议要求时保留宽 tag
fixtures/bad/zp-bool-array.zig:2:11: info[zp-bool-array bool-array] 用 bool 数组/切片存位标志 / array/slice of bool used as a bit set: [4096]bool = 4096 字节，bit set 只需 512 字节
    建议: 改用 std.bit_set.Static(N) / std.bit_set.Dynamic，省 8 倍内存，且可按字批量运算
fixtures/bad/zp-bool-array.zig:3:48: info[zp-bool-array bool-array] 用 bool 数组/切片存位标志 / array/slice of bool used as a bit set: []bool
    建议: 改用 std.bit_set.Static(N) / std.bit_set.Dynamic，省 8 倍内存，且可按字批量运算
fixtures/bad/zp-bool-array.zig:4:32: info[zp-bool-array bool-array] 用 bool 数组/切片存位标志 / array/slice of bool used as a bit set: gpa.alloc(bool, ...)
    建议: 改用 std.bit_set.Static(N) / std.bit_set.Dynamic，省 8 倍内存，且可按字批量运算
fixtures/bad/zp-bool-array.zig:7:21: info[zp-bool-array bool-array] 用 bool 数组/切片存位标志 / array/slice of bool used as a bit set: []const bool
    建议: 改用 std.bit_set.Static(N) / std.bit_set.Dynamic，省 8 倍内存，且可按字批量运算
fixtures/bad/zp-static-string-map.zig:3:9: info[zp-static-string-map static-string-map] StringHashMap 只用字面量键填充 / StringHashMap populated only with literal keys: `map` 共 3 次 put，全部为字面量键
    建议: 键在编译期已知时用 std.StaticStringMap(V).initComptime(.{ ... })：零分配、零初始化

共检查 5 个文件，发现 8 处（warning 2, info 6, hint 0）
$ echo $?
1
```

行内忽略：`// zperf-lint: ignore zp-alloc-hot`（作用于本行和下一行），文件级：`// zperf-lint: ignore-file zp-packable-bools`。本文 `examples/` 中几个故意写成反例的地方就用了这种注释，`zperf-lint examples/` 结果为 0 处。

**v0.3 新增**：
- zp-queue-ordered-remove 把 `ArrayList` 当队列（`orderedRemove(0)`，或在循环里 `orderedRemove`）；
- zp-shift-on-read 读走前缀后把剩余数据整体搬回开头（`copyForwards(buf[0..], buf[k..])`、`@memmove`、`replaceRange(…, 0, n, &.{})`）；
- zp-per-packet-alloc 逐包/逐帧热函数里的堆分配。热函数按名字推断（`on*`、`handle*`、`recv*`、`enqueue`、`tick` 等），也可以用 `// zperf-lint: hot` 标注或 `--hot-fn` 指定，并沿本文件调用传播两层。消息末尾的 `[热: pump(标注 hot) → stash]` 是原因链；
- zp-invariant-float-div 循环里除以一个循环不变的浮点数。没有 fast-math 时编译器不会把它改写成乘以倒数，ReleaseFast 也不开 fast-math（见 §5.7）。

另外，Zig 0.16 代码里的 `.{x} ** N` 会先按等长替换再解析（0.17 分词器已去掉 `**`）。

**自举时学到的一条**：`Ast.tokenLocation(0, tok)` 每次都从文件头扫描，是 O(文件长度)。对每条发现、每个函数都调用它，就会变成 O(n²)：zperf-lint v0.3 的规则阶段曾是解析阶段的 4 倍。正确做法是解析后一次扫描，建一张行首偏移表，之后二分查找。再加上每文件 arena `reset(.retain_capacity)`（§2.2）和 `Io.Group` 并行、各写各槽（§6.2），在 Zig 0.17 std（563 个文件）上从 527 ms 降到 41 ms，峰值 RSS 从 64 MiB 降到 17 MiB，输出逐字节不变。详见 `zperf-lint/README.md` 的“自举 / dogfooding”。

**局限**：它是语法级检查，没有类型信息——结构体大小是按字段类型估算的，"是否是整数除法"无法判断，"所有权是否转移"靠 token 启发式。每条规则的误报风险都写在 README 里；把它当成 code review 的提示，而不是编译器错误。

### 与社区 linter 搭配

社区已有 4 个 Zig linter：[ZLint](https://github.com/DonIsaac/zlint)（正确性）、[ziglint](https://github.com/rockorager/ziglint)（风格 / 废弃 API）、[zwanzig](https://github.com/forketyfork/zwanzig)（ZIR 路径敏感分析）、[zbc](https://github.com/ericsssan/zbc)（生命周期 / 所有权，100 条规则）。在 Zig 0.17.0 下实测：ZLint 预编译包和 zbc 源码构建都能用；ziglint 只有预编译包能用（源码不兼容 0.17）；zwanzig 明确不支持 0.17，只能用内嵌 0.16 前端的预编译包，误报较多。它们关注的是正确性和风格，zperf-lint 的 19 条规则里有 15 条没有任何工具覆盖。zp-missing-free 与 zbc 是互补关系：zbc 不报"局部分配从不释放"，zp-missing-free 查不到"`create(Self)` 但 `deinit` 不 `destroy(self)`"。用 zbc 跑本文示例发现了 `p04` 解释器缺少栈深前置条件，借助 zbc 还修掉了 zp-missing-free 对 `return list.items` 的漏报。

推荐组合：zperf-lint（性能）+ zbc（内存安全）+ ZLint（正确性）作为阻断项，ziglint / zwanzig 只报告。统一入口是 `zig run scripts/repo.zig -- lint-all`；伞形仓库 CI 见根目录 `.github/workflows/ci.yml`（job `zperf`），说明见 `packages/zperf/ci/README.md`。完整的兼容性、结果、规则重叠表见[社区工具对比](../community-tooling.md)。

---

## 10. 速查表

**省内存**

| 想要 | 用 |
|---|---|
| 一批同寿命的临时分配 | `ArenaAllocator` + `reset(.retain_capacity)` |
| 限制 keepalive 保留的 arena RSS | `reset(.{ .retain_with_limit = N })`（§2.2） |
| 零堆分配 | `FixedBufferAllocator` / `ArrayList.initBuffer` |
| 常见情况小、偶尔大 | `BufferFirstAllocator`（0.17） |
| 大量同类对象 | `MemoryPool(T)` |
| 等长字节缓冲 | size-class 池 + `tryAlloc`（§2.4） |
| 不可预测的分配延迟 | 启动静态分配 + 阶段包装 + 按并发定容（§2.5） |
| 去 padding、按字段遍历 | `MultiArrayList(T)` |
| 多个标志 | `packed struct(u8)` / `EnumSet` / `bit_set` |
| 引用 | `enum(u32) { none = maxInt(u32), _ }` 句柄；可重定位 slab 上的偏移（§2.17） |
| 空闲物理回收（保留 VA） | 压缩冷页 + `madvise(DONTNEED)`（§2.17，上游） |
| 字符串 | interning（bytes + u32 偏移）、SSO |
| 查找且不先 `dupe` | `getOrPutAdapted` / `StringIndexAdapter`（§2.11） |
| 经常遍历整张表 | 优先 `ArrayHashMap` |
| 可选标量 | 哨兵值代替 `?u32` |
| 编译期已知的映射 | `EnumArray` / `StaticStringMap.initComptime` |
| 读大文件 | `File.createMemoryMap` + 零拷贝切片 |
| 可增长环 | `Deque`（尽量走 `Allocator.remap`） |

**算得快**

| 想要 | 用 |
|---|---|
| 运行时零成本的表/特化 | `comptime` 块、`comptime` 参数、`inline for` |
| 数据并行 | `@Vector` + `@reduce`/`@select`/`@shuffle`（0.16/0.17 自动向量化关闭） |
| 字节查找 / 比较 | `std.mem.findScalar` / `std.mem.eql`（优先于手写循环） |
| 排序 | `std.sort.pdq`（默认；§5.10） |
| 难预测的分支 | `@intFromBool`、`@min/@max`、`@select`、`@branchHint(.unpredictable)` |
| 状态机/解释器 | labeled switch `continue :label` |
| 单二进制内按 ISA 选 crypto/SIMD | `builtin.cpu.has` + comptime `@import`（§5.2） |
| 冷路径 | `@branchHint(.cold)` |
| 局部去检查 | 最小作用域内 `@setRuntimeSafety(false)` |
| 快速浮点 | `@setFloatMode(.optimized)`、`@mulAdd` |
| 避免除法 | 2 的幂容量 + `&`、编译期常量除数、`@divCeil` |
| 多线程 | `Io.Group.async`、每任务独立槽位、`align(std.atomic.cache_line)` |
| 少系统调用 | 带缓冲的 `Io.Writer` + `flush`、`writeSplat` / drain、`Io.Batch`、io_uring |
| 格式化进内存 | `Io.Writer.Allocating`（取走前 flush 基本为空） |
| 构建 | `-O fast`、`-mcpu`、`-flto`、`-fstrip`、`-fsingle-threaded` |

---

## 参考资料

官方：

- [Zig 下载页（版本与日期）](https://ziglang.org/download/)
- [0.17.0 Release Notes](https://ziglang.org/download/0.17.0/release-notes.html) · [0.16.0](https://ziglang.org/download/0.16.0/release-notes.html) · [0.15.1](https://ziglang.org/download/0.15.1/release-notes.html) · [0.14.0](https://ziglang.org/download/0.14.0/release-notes.html)
- [Zig 0.17.0 语言参考](https://ziglang.org/documentation/0.17.0/)
- Zig 0.17.0 标准库源码：`lib/std/heap.zig`、`heap/SmpAllocator.zig`、`heap/SafeAllocator.zig`、`heap/ArenaAllocator.zig`、`heap/BufferFirstAllocator.zig`、`heap/memory_pool.zig`、`multi_array_list.zig`、`mem.zig`、`hash_map.zig`、`deque.zig`、`sort.zig`、`bit_set.zig`、`enums.zig`、`static_string_map.zig`、`simd.zig`、`crypto/aes.zig`、`Io.zig`、`Io/Writer.zig`、`Io/File/MemoryMap.zig`、`os/linux/IoUring.zig`、`start.zig`、`debug.zig`、`zig/Ast.zig`、`zig/Zir.zig`、`zig/tokenizer.zig`
- [PR #7920：AST 内存布局重做](https://github.com/ziglang/zig/pull/7920) · [PR #15569：InternPool](https://github.com/ziglang/zig/pull/15569)
- [Issue #15137：PGO（not planned）](https://github.com/ziglang/zig/issues/15137) · [Issue #237](https://github.com/ziglang/zig/issues/237) · [Issue #1018：函数多版本](https://github.com/ziglang/zig/issues/1018)

社区：

- Andrew Kelley：[A Practical Guide to Applying Data-Oriented Design（Handmade Seattle 2021）](https://handmade-seattle.com/media-sub/practical-data-oriented-design) · [文字稿](https://josherich.me/podcast/andrew-kelley-practical-data-oriented-design-dod)
- TigerBeetle：[TIGER_STYLE.md](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)
- matklad：[Reserve First](https://matklad.github.io/2025/08/16/reserve-first.html) · [Zig defer Patterns](https://matklad.github.io/2024/03/21/defer-patterns.html) · [Push Ifs Up And Fors Down](https://matklad.github.io/2023/11/15/push-ifs-up-and-fors-down.html)
- Mitchell Hashimoto：[Zig Parser](https://mitchellh.com/zig/parser) · [关于 Ghostty 使用 Highway 做运行时 SIMD 分发](https://whnex.com/items/49012420)
- Bun：[PR #19134 Use Highway SIMD](https://github.com/oven-sh/bun/pull/19134)
- [oma：Zig 运行时 SIMD 分发](https://github.com/ATTron/oma) · [ziggit 讨论](https://ziggit.dev/t/oma-runtime-simd-dispatch-for-zig/14438)
- [poop](https://github.com/andrewrk/poop)
- 视频灵感：刘严鹏「写代码省内存」 <https://v.douyin.com/KoVqTHbb9L0/>

### 语料 / 上游性能案例

- TigerBeetle：[`static_allocator.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/static_allocator.zig) · [`message_pool.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/message_pool.zig) · [performance concepts](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/concepts/performance.md)
- http.zig：[issue #176 RSS / retain](https://github.com/karlseguin/http.zig/issues/176) · [issue #199 buffer pool](https://github.com/karlseguin/http.zig/issues/199)
- Ghostty：终端 `Offset` / page mmap · [PR #13264 scrollback compression](https://github.com/ghostty-org/ghostty/pull/13264) · [PR #13537 resize/reflow](https://github.com/ghostty-org/ghostty/pull/13537)
- 研究笔记（非正式指南正文）：`zig-perf-research/import-backlog.md`、`corpus-perf-patterns.md`、`upstream-perf-issues.md`、`zig-lang-perf-patterns.md`
- Zig 语言语料（稀疏克隆）：`zig-corpus/zig` @ `8f0c6ce4`（Codeberg `ziglang/zig`）；编译器 `src/InternPool.zig` 用于分片引用
