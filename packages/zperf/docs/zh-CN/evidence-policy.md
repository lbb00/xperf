# zperf 证据政策

## 门槛

只有在 `packages/zperf/evidence/` 下同时存在以下两项时，zperf 规则才可以被记录/视为 **速度 `错误`**（cperf/jsperf 风格升级）:

1. `<RULE>.md` — 声明、利用、Zig 版本 / 优化模式、限制
2. `<RULE>.jsonl` — ≥1 个前/后行，包含字段 `rule`、`case`、`role`、`zig`、`optimize`、`median_ms`、`ops`、`ratio`、`ts`

否则保持 **rules.zig** 的严重性（`warning` / `info` / `hint` / `off`），并将其视为评论提示，而不是“必须修复以提高速度”的 CI 门控。

拥有 JSONL 是**必要的，但不充分的**。只有当实际时间明显同意**并且**故障模式符合规则时才升级。适度的比例、依赖环境的 I/O 或优化器省略的基准仍然保持非错误。

今天的 CLI 仍可能因任何发现而使流程失败；此政策是 **保留 / 升级** 合同，直到预设生效。

## 当前映射

截至2026-10-22：使用 Zig **0.17.0** `-Ofast` 测量，取 9 次运行的中位数，测试工具 `examples/bench/evidence_fill.zig`。

**G3/r4 (2026-10-22)：** 在对成熟的 Zig 语料库进行 OK-idiom 大规模测试后，若干规则降级为默认 **`关闭`**（参见 [corpus.md](corpus.md)；门控定义见 [AGENT.md](../../../../zh-CN/AGENT.md)）。这些规则的证据 JSONL 文件仍然有效；在未对默认开启集合重新验证 G4 之前，**不要**将其升级为 `error`。

| 规则 | rules.zig sev | 证据 | 测量比率 | 升级？ |
|------|---------------|----------|-----------|-----------|
| zp-alloc-hot | 关闭 | [zp-alloc-hot](../../evidence/zh-CN/zp-alloc-hot.md) | 相对于 arena 保留约 **1.4×** GPA | **否**（适中；对于固定大小更推荐使用 zp-create-destroy-hot / zp-fixed-size-alloc-hot） |
| zp-append-without-reserve | 关闭 | [zp-append-without-reserve](../../evidence/zh-CN/zp-append-without-reserve.md) | ~**2.1×** | 否（信息） |
| zp-page-allocator-small | 警告 | [zp-page-allocator-small](../../evidence/zh-CN/zp-page-allocator-small.md) | ~**341×** 页面 vs GPA | **候选错误** |
| zp-print-hot | 关闭 | [zp-print-hot](../../evidence/zh-CN/zp-print-hot.md) | ~**6e4×** 打印对比安静 | 否 — 环境 I/O（如 jsperf 的 jp-console-hot） |
| zp-unbuffered-io | 关闭 | [zp-unbuffered-io](../../evidence/zh-CN/zp-unbuffered-io.md) | ~**49×** 空 vs 4KiB | **候选错误** |
| zp-aos-single-field | 关闭 | [zp-aos-single-field](../../evidence/zh-CN/zp-aos-single-field.md) | ~**6.6×** AoS 对比 SoA | 否（审查提示） |
| zp-bool-array | 关闭 | [zp-bool-array](../../evidence/zh-CN/zp-bool-array.md) | ~**30×** bool[] 对比 bitset | 否（信息） |
| zp-static-string-map | 信息 | [zp-static-string-map](../../evidence/zh-CN/zp-static-string-map.md) | ~**2.5×** | 否（信息） |
| zp-runtime-div-hot | 关闭 | [zp-runtime-div-hot](../../evidence/zh-CN/zp-runtime-div-hot.md) | 约 **12×** 模与掩码 | 否（审查提示） |
| zp-queue-ordered-remove | 警告 | [zp-queue-ordered-remove](../../evidence/zh-CN/zp-queue-ordered-remove.md) | ~**466×** orderedRemove 与 ring | **候选错误** |
| zp-shift-on-read | 警告 | [zp-shift-on-read](../../evidence/zh-CN/zp-shift-on-read.md) | ~**17×** | **候选错误** |
| zp-per-packet-alloc | 关闭 | [zp-per-packet-alloc](../../evidence/zh-CN/zp-per-packet-alloc.md) | 共享 zp-alloc-hot ~1.4× | 否（与 zp-alloc-hot 相同） |
| zp-不变浮点除法 | 提示 | [zp-不变浮点除法](../../evidence/zh-CN/zp-invariant-float-div.md) | ~**2.0×** | 保持提示 |
| zp-map-put-without-ensure | 关闭 | [zp-map-put-without-ensure](../../evidence/zh-CN/zp-map-put-without-ensure.md) | ~**2.8×** | 否（信息） |
| zp-arena-reset-free-all | 警告 | [zp-arena-reset-free-all](../../evidence/zh-CN/zp-arena-reset-free-all.md) | ~**3.2×** free_all 与 retain | 临界警告 |
| zp-create-destroy-hot | 信息 | [zp-create-destroy-hot](../../evidence/zh-CN/zp-create-destroy-hot.md) | ~**11×** | **候选错误** |
| zp-fixed-size-alloc-hot | 信息 | [zp-fixed-size-alloc-hot](../../evidence/zh-CN/zp-fixed-size-alloc-hot.md) | ~**8.5×** | **候选错误** |
| zp-open-file-hot | 提示 | [zp-open-file-hot](../../evidence/zh-CN/zp-open-file-hot.md) | ~**2134次** 打开一次 | 否（提示；路径可能会改变） |
| zp-clock-hot | 提示 | [zp-clock-hot](../../evidence/zh-CN/zp-clock-hot.md) | ~**42×** 样本一次 | 否（提示；新的时间戳没有可提升的内容） |
| zp-json-hot | 提示 | [zp-json-hot](../../evidence/zh-CN/zp-json-hot.md) | ~**2683×** 解析一次 | 否（提示；不可提升可变的有效负载） |
| zp-alloc-print-hot | 提示 | [zp-alloc-print-hot](../../evidence/zh-CN/zp-alloc-print-hot.md) | ~**50×** GPA 打印一次；arena ~**12×** | 否（提示；一个变化的值不能被提升） |

### 本次未测量 / 不适用

| 规则 | 状态 | 原因 |
|------|--------|-----|
| zp-debug-allocator | **不适用（仅限静态）** | 构建模式分配器选择；非单一二进制前/后 |
| zp-large-struct-by-value | **结论不明确** | ReleaseFast 通过值传递与指针微基准测试省略 (~50 ns 总计) — 不可引用 |
| zp-missing-free | **不适用（正确性）** | 缺少 free/deinit — 导致内存泄漏/未定义行为，不影响速度 |
| zp-broad-runtime-safety | **待定措施** | 广泛的 `@setRuntimeSafety(false)` —— 仅在 ReleaseSafe 下有意义 |
| zp-packable-bools | **待测量** | 可打包布尔值——密度声明；尚无 wall JSONL |
| zp-usize-index-field | **待定措施** | usize 索引字段 — 密度；尚无 wall JSONL |
| zp-catch-unreachable-alloc | **不适用（正确性）** | 在 alloc 上使用 `catch unreachable` — OOM 时未定义行为 |
| zp-oversized-enum-tag | **不适用（静态大小）** | 超大枚举标签 — ABI/大小；无墙 JSONL |
| zp-optional-scalar-field | **待定测量** | 可选标量填充——密度；尚无 wall JSONL |
| zp-catch-unreachable-io | **不适用（正确性）** | 在 I/O 上 `catch unreachable` |

## 再生

```sh
bash packages/zperf/scripts/regen-evidence.sh
bash packages/zperf/scripts/regen-evidence.sh
```

在 Zig 次要升级后重新运行；如果比率发生显著变化，更新匹配的 `.md` 中位数。

## 候选错误（策略，目前还不是 CLI 预设）

这些测量结果高度一致：**zp-page-allocator-small, zp-queue-ordered-remove, zp-shift-on-read, zp-create-destroy-hot, zp-fixed-size-alloc-hot**（zp-unbuffered-io 在 G3 OK-idiom 后被降级关闭）。

在 `--preset` 到达之前保持为警告/信息；在没有 G4 + preset 的 CI 中不要生成 `error`。r4 之后默认开启：zp-page-allocator-small、zp-broad-runtime-safety、zp-static-string-map、zp-queue-ordered-remove、zp-shift-on-read、zp-invariant-float-div、zp-arena-reset-free-all、zp-create-destroy-hot、zp-fixed-size-alloc-hot。
