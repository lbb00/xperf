# XPerf —— 还缺什么（同一 playbook）

来自闭环：**指南 ↔ 实测证据 ↔ 语料 dogfood ↔ 反向优化 ↔ 目标语言实现 ↔ 诚实边界**。

## 已经验证（保持）

- 同语言检查器（Zig / C / JS）+ self-lint = 0。
- 语料反向优化提升的是**精度**，本身不等于应用变快。
- 静态味道 ↔ 运行时：**部分**（jsperf STATIC-VS-V8；**cperf STATIC-VS-O2**）；每个规则族都要重新验证。
- 跨 kit 目录：[smell-catalog.md](smell-catalog.md)。
- 引擎语料（gcc/Node）作为「找加速」很弱；作为误报磨坊很强。

## 下一步高杠杆

### 1. 发现 → 基准门禁（**jp-delete-shape / jp-delete-array-hole / cp-alloc-hot 已完成**）
每条**保留**的规则在命名运行时（cc -O2 / Node 版本 / Zig ReleaseFast）上需要 ≥1 对夹具的 JSONL before/after。
以 `packages/*/evidence/<rule-id>.jsonl` + 指南引用交付。
在此之前，把 lint 只当评审提示（已是事实；做成机械门槛）。

### 2. 严重级别 / 模式（cperf/jsperf 中**已完成**）
- `error`：仅有实测同意的规则（如 jsperf jp-delete-array-hole、cperf cp-alloc-hot）。
- `hint` / 默认 off：cp-printf-hot、jp-console-hot、jp-alloc-hot。
- 配置：`--preset app|engine|all` + `--severity RULE=…` + `--strict-hints`。

### 3. 动态配套（不是更多静态规则）
| Kit | 配套 | 目的 |
|-----|------|------|
| jsperf | `--trace-deopt` / Perf harness（已起步） | JIT 真相 |
| cperf | 对 examples 包一层 `perf stat` / cachegrind | I/O vs 分配迷思 |
| zperf | 现有 bench + 可选 tracy | 保持 |
| jvmperf | JMH + EaProbe / `STATIC-VS-HOTSPOT`（已起步） | HotSpot 墙钟与 B/op；不是 PrintCompilation 计数 |

静态回答「可能伤」；动态回答「在这里确实伤了」。

### 4. 盯自己的热代码，而不只是上游引擎
把语料指向**用户/产品树**（以及 jsperf 的小程序 / 嵌入 JS）。
成功指标：带基准的可行动真阳性，不是残留计数 ↓。

### 5. 跨 kit「同一味道，三种语言」（**目录已落地**）
见 [smell-catalog.md](smell-catalog.md)。规则出现时填空单元格（C 布局规则）。
逼出诚实的可移植声明（V8 ≠ QuickJS ≠ C）。

### 6. jvmperf 槽位
已在 `packages/jvmperf/` **落地**（`jvmperf-lint`、指南、JMH）。证据门禁与对照：`docs/evidence-policy.md`。

### 7. CI dogfood
PR 上跑 `make self-lint` / `npm run self-lint` / `zig build`；语料 lint 在钉死的 SHA 上**夜间**跑（不是每次提交）。

### 8. 负面结果作为一等文档
把负面结果当一等文档发布 —— jsperf STATIC-VS-V8 + **cperf STATIC-VS-O2**（`#if 0` cp-printf-hot）已完成；继续扩展。

## 明确的非目标（目前）

- 完整 AST/类型检查级分析。
- 声称引擎 lint 合计 = 性能收益。
- 仅从源码检测 JIT 层级 / IC 状态。

## 建议顺序

1. ~~严重级别拆分 + app preset（c/js）~~ —— **完成**。
2. ~~jp-delete-shape / jp-delete-array-hole / cp-alloc-hot 的证据 JSONL~~ —— **完成**；见各 kit 的 `evidence/`。
3. 一份产品/嵌入语料，而不是更多 gcc。
4. ~~cperf 静态 vs `-O2`~~ —— **完成**（对照套件保留在仓库外）。
5. ~~跨 kit smell 目录草稿~~ —— **完成**：[smell-catalog.md](smell-catalog.md)；填剩余证据单元格。
6. 动态配套（对 cperf examples 跑 `perf stat`）。
