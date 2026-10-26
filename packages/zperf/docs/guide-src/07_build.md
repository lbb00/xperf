## 7. Builds and tooling

### 7.1 Optimization modes and common options (0.17 names)

| Goal | `zig build-exe` flag | `build.zig` | Notes |
|---|---|---|---|
| Maximum speed | `-O fast` | `-Doptimize=fast` | Disables safety checks. Since 0.17, tags are `.debug/.safe/.fast/.small`; old names such as `ReleaseFast` changed. |
| Release build with checks | `-O safe` | `-Doptimize=safe` | Recommended default for production; disable checks locally with `@setRuntimeSafety(false)` only in verified hot code. |
| Minimum size | `-O small` | `-Doptimize=small` | |
| Target CPU | `-mcpu native` / `-mcpu x86_64_v3` | `-Dcpu=native` | Do not use `native` for binaries distributed to other machines; see §5.2. |
| LTO | `-flto` / `-fno-lto` | `exe.lto = .full` (`std.zig.LtoMode`: `none/full/thin`) | Requires the LLVM backend. |
| Strip symbols | `-fstrip` | `.strip = true` (Module option) | |
| Single-threaded | `-fsingle-threaded` | `.single_threaded = true` | Atomics and locks can be simplified; `smp_allocator` is unavailable. |
| Remove unwind tables | `-fno-unwind-tables` | `.unwind_tables = .none` | Reduces size but affects stack traces. |
| Frame pointer | `-fomit-frame-pointer` | `.omit_frame_pointer = true` | Keep frame pointers when using `perf` to inspect call stacks. |
| Stack report | `-fstack-report` | | Reports stack usage for each function. |
| libc | `-lc` | `.link_libc = true` | With libc linked, `init.gpa` uses `c_allocator` in Fast mode. |

`examples/build_example/` builds with `zig build -Doptimize=fast`:

> Example: `examples/build_example/build.zig` (checked with Zig 0.17.0 using `zig build -Doptimize=fast`).

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{}); // -Dtarget=... -Dcpu=native
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize != .debug,
            .single_threaded = false,
            .unwind_tables = .none,
            .omit_frame_pointer = true,
        }),
    });
    exe.lto = .full;
    b.installArtifact(exe);
}
```

**Local size check (x86_64 Linux):** same tiny alloc/clear program → 217,712 bytes (`-Doptimize=fast`) vs 123,696 (`-Doptimize=small`). Scale only, not a general benchmark.

### 7.2 Reduce binary size

- Combine `-O small`, `-fstrip`, and `-fno-unwind-tables`; add `-fsingle-threaded` only when the program is single-threaded.
- Avoid many distinct `std.fmt` format strings. Each format-string and argument-type combination can instantiate another generic formatting implementation. In 0.16, “Lazy Field Analysis” stopped pulling in the whole vtable when `std.Io.Writer` was used only as a namespace, reducing unnecessary code generation.
- Zig 0.16's “Improved Code Generation of For Loop Safety Checks” reduced generated code for slice iteration by about 30%, according to the release notes.

### 7.3 PGO

Zig does **not** support PGO for user programs as of this writing. [#15137](https://github.com/ziglang/zig/issues/15137) is “not planned”; research [#237](https://github.com/ziglang/zig/issues/237) on test-driven PGO is still open. Fallbacks: branch hints, hot/cold separation, data layout.

Sources: `zig build-exe --help` (0.17.0) · [0.17 rename of lang.OptimizeMode to lang.Optimize](https://ziglang.org/download/0.17.0/release-notes.html) · [0.16 Lazy Field Analysis and loop safety-check code generation](https://ziglang.org/download/0.16.0/release-notes.html) · `lib/std/Build/Step/Compile.zig`

### 7.4 Patterns from the Zig compiler / std (short)

Useful when building tools that look like compilers (parsers, LSs, bundlers). Full notes: `zig-perf-research/zig-lang-perf-patterns.md` (corpus `zig-corpus/zig` @ `8f0c6ce4`).

| Pattern | Where | Takeaway |
|---|---|---|
| Empirical `ensureTotalCapacity` | `lib/std/zig/Ast.zig` | Reserve from measured ratios to input size (§2.6) |
| SoA + `extra` + `string_bytes` | `lib/std/zig/Zir.zig` | Dense IR; rare ops out of line (§2.8) |
| Sharded intern + tid indices | `src/InternPool.zig` | Concurrent intern without a global lock (§2.10) |
| Labeled-switch tokenizer | `lib/std/zig/tokenizer.zig` | Same as §5.4; keywords via `StaticStringMap` |
| Optional tracy hooks | `src/tracy.zig` | Instrument self-host builds when chasing compile time (**U**) |
| Content-addressed build cache | `lib/std/Build/Cache.zig` | SipHash manifests for incremental artifacts (§8.4 adjacent) |

Do not cargo-cult compiler internals into small apps. Steal the **shape** (indices, SoA, shard, ensure heuristics) after measuring.

---

