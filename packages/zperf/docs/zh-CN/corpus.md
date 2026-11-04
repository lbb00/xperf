# zperf 语料库目标

大型树木**不会**被供应商化，并且语料库不会随仓库一起发布：将其克隆到仓库外的任意本地目录，并将该路径传递给代码检查器。使用以下命令进行检查：

```sh
cd packages/zperf/zperf-lint && zig build -Doptimize=fast
cd packages/zperf/zperf-lint && zig build -Doptimize=fast
./zig-out/bin/zperf-lint --no-fail -f json <corpus-dir>/<tree>
./zig-out/bin/zperf-lint --no-fail -f json <corpus-dir>/<tree>
```

## 固定目标

克隆于 2026-10-22（亚洲/上海）。

| 树 | 链接 | 提交 | 大小 | `.zig` |
|------|-----|--------|------|-------:|
| **zig** (`lib/std`, `src`) | https://codeberg.org/ziglang/zig.git | `8f0c6ce407f9` | 总计 312M 的一部分 | 1072 个遍历树 |
| **tigerbeetle** (`src/`) | https://github.com/tigerbeetle/tigerbeetle.git | `0450c32b2c3c` | 14M | 248 |
| **ghostty** | https://github.com/ghostty-org/ghostty.git | `67edd20a0292` | 63M | 603 |
| **http.zig**（次要） | https://github.com/karlseguin/http.zig.git | `e8272bfd5727` | 1.1M | 33 |

主要 G2 套装：**zig（标准库 + 编译器）** + **tigerbeetle** + **ghostty**（≥3 个大型生产树）。
http.zig 是一个精简的辅助套装。

检查器是 **Zig**，`std.zig.Ast`，同语言。默认路径跳过：tests / Build / benchmarks / **fuzz** / scripts / `compiler_rt`（参见 [`zperf-lint/README.md`](../../zperf-lint/README.md)）。

## G3/r4 结果（2026-10-22）

在默认规则映射下，每次运行的计数：r1 → r3 → **r4**。

| Tree | r1 → r3 → **r4** (defaults) |
|------|------------------------------|
| **zig** `lib/std` | **403 → 391 → 12** |
| **zig** `src` (编译器) | **859 → 856 → 3** |
| **tigerbeetle** `src/` | **252 → 184 → 1** |
| **ghostty** | **441 → 425 → 9** |
| **http.zig**（次要） | **25 → 24 → 1** |

**G3/r4 之后默认关闭**（成熟 Zig 上的 OK-习惯集合）：zp-alloc-hot、zp-append-without-reserve、zp-debug-allocator、zp-large-struct-by-value、zp-print-hot、zp-unbuffered-io、zp-missing-free、zp-packable-bools、zp-usize-index-field、zp-aos-single-field、zp-catch-unreachable-alloc、zp-oversized-enum-tag、zp-optional-scalar-field、zp-bool-array、zp-runtime-div-hot、zp-per-packet-alloc、zp-map-put-without-ensure、zp-catch-unreachable-io。CLI 不会报告 `off` 规则（请参见 [`zperf-lint/README.md`](../../zperf-lint/README.md#rules)）。

**默认开启：** zp-page-allocator-small, zp-broad-runtime-safety, zp-static-string-map, zp-queue-ordered-remove, zp-shift-on-read, zp-invariant-float-div, zp-arena-reset-free-all, zp-create-destroy-hot, zp-fixed-size-alloc-hot.

### 反向优化 + 降级

- 路径跳过：`*fuzz*.zig`，`**/fuzz/**`（合并到 `--include-tests` 中）
- zp-page-allocator-small：精确匹配 `page_allocator` / `*.page_allocator`（不包括 `huge_page_allocator`）
- zp-debug-allocator：仅匹配 `DebugAllocator(` / `GPA(` 实例化；跳过重新导出和测试上下文
- zp-print-hot：跳过 `if (log)` / `if (logging)` 诊断门控
- **r4:** 将几乎所有 OK-idiom 规则降级为默认 **`off`**；保留带有 TP 的规则（上面默认开启列表）在默认映射中开启

### 语料库准备：**是**

G3 + r4 降级完成。全 r4 剩余样本 **n=26**：TP **73.1%**，OK-idiom **26.9%**，FP+DOC+SKIP-path **0%**。在 zp-queue-ordered-remove / zp-shift-on-read / zp-broad-runtime-safety / zp-fixed-size-alloc-hot 上真实 TP。没有 G4 不会大规模升级。

## 库存

```text
<corpus-dir>/
<corpus-dir>/
  zig/            # symlink → zig-corpus/zig
  zig/            # symlink → zig-corpus/zig
  tigerbeetle/    # symlink
  tigerbeetle/    # symlink
  ghostty/        # symlink
  ghostty/        # symlink
  http.zig/       # symlink (secondary)
  http.zig/       # symlink (secondary)
```

不要将语料来源提交到 `packages/zperf`。
