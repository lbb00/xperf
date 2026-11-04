# XPerf 使用手册

用于 **XPerf** 系列的操作方法。每个套件使用相同的循环；证据和语料库保持在套件本地。

**代理:** 遵循根 [AGENT.md](../../zh-CN/AGENT.md) 门 **G0–G7**。此操作手册是人工叙述；如果其与 AGENT.md 在流程上有分歧，**以 AGENT.md 为准**。特别是：没有 **TP/FP 分级 (G3)** 的语料是不完整的。

## 循环

```mermaid
flowchart TB
flowchart TB
  inventory --> evidence --> corpus["corpus lint"] --> triage["TP / FP triage"]
  inventory --> evidence --> corpus["corpus lint"] --> triage["TP / FP triage"]
  triage --> reverse["reverse-opt"] --> dogfood --> docs
  triage --> reverse["reverse-opt"] --> dogfood --> docs
```

1. **清单** — 列出指南章节、缺失的证据、lint规则覆盖范围。
2. **证据** — 在 `-O2` / ReleaseFast / 等效位置下的 JSONL（或本地语言）微基准；记录机器和标志。在默认 `error`（代理 **G4**）之前必须完成。
3. **语料库 lint** — 浅克隆 ≥3 个真实项目；运行检查器（代理 **G2**）。
4. **TP/FP 分类** — 对残余样本进行抽样；标记 TP / FP / OK-惯用法 / 文档 / 跳过路径；编写 `TRIAGE-*.md`（代理 **G3** — **必填**，非可选）。
5. **反向优化** — 收紧规则、跳过路径、为 FP 类添加好的固定测试；重新运行语料库差异。
6. **自用测试** — 检查器 + 示例清理；不良固定测试为故意设置（代理 **G0/G1**）。
7. **文档** — 干练语气审查；更新 `corpus.md` + 注册表。

## 语料循环（软件包）

语料库按套件命名（第一次内部测试轮次 2026-10-21 亚洲/上海；后续轮次在每个套件的 `docs/corpus.md` 中）。克隆保留在仓库外；软件包只保留 `docs/corpus.md` 和指南引用。

| 包 | Lint | 内部使用的语料库 (r1–r3) | 与发现相关的指南章节 |
|---------|------|---------------------------|----------------------------------|
| **cperf** | `cperf-lint` cp-alloc-hot–cp-strcat-hot | quickjs, lua, gcc（sparse）, sqlite `src/` | `01_allocation`（cp-alloc-hot, cp-realloc-grow-one）, `02_hot_io`（cp-printf-hot dump/codegen） |
| **jsperf** | `jsperf-lint` jp-alloc-hot–jp-map-filter-chain | Node `lib/`, Preact `src/`, quickjs `*.js`, TypeScript `packages/typescript/src` + V8 基准测试 | `01`…`03`, **`04_v8_optimizations`** (lint≠JIT; `STATIC-VS-V8.md`) |
| **zperf** | `zperf-lint` | zig 标准库 + 选定应用程序（参见 zperf 文档） | 完整英文 |
| **jvmperf** | `jvmperf-lint` 29 个活跃规则，`packages/jvmperf/docs/rule-ids.md` 中的标识 | okhttp, retrofit, kotlinx.coroutines, guava `src`, vert.x, fastjson2, jetty-core, netty buffer+common | 带 JMH/JOL 证据的英文; `packages/jvmperf/docs/corpus.md` |

重新运行：路径/目录跳过 → 规则抑制 → 套件 `docs/corpus.md` 中的前/后表格。不要将剩余计数视为壁钟时间声明。

## 每套包裹的交付物

- 使用章节草稿的指南 → 随时间测量的声明
- 使用 `--format text|json`、`--preset app|engine|all`、`--severity RULE=error|hint|off` 进行检查；仅在发现 **错误** 时退出非零（可选 `--strict-hints`、`--no-fail`）
- `fixtures/good` / `fixtures/bad` 用于 2–3 个入门规则
- Git 之外的研究笔记

## 严重性和预设 (cperf / jsperf 0.3.x)

默认 **`app`**：保留与测量到的痛点相关的规则作为 `error`（C：cp-alloc-hot 和 cp-realloc-grow-one；JS：jp-delete-array-hole）；将噪声大、语料库密集的规则降级到 `hint` 或 `off`（C：cp-printf-hot 和 cp-strcat-hot 关闭；JS：jp-alloc-hot、jp-console-hot 和 jp-delete-shape 关闭，jp-map-filter-chain 提示）。JS `jp-string-plus-in-loop` 在 `push` + `join` 出现约 2 倍失误后被移除。**`engine`** 保持相同思路，并为引擎树增加一些提示。**`all`** 恢复“每个发现都失败”（0.3 之前的行为）。提示仍然打印；除非 `--strict-hints`，否则不会导致 CI 失败。优先选择证据门而不是残留计数。

## 还有什么

见 [roadmap-next.md](roadmap-next.md) — 接下来的循环使用相同的方法（证据门、严重性、动态伴侣、自有语料库）。

## 跨套件气味

参见 [smell-catalog.md](smell-catalog.md) — 循环内分配 / 布局 / 热 IO / 多孔 / 删除映射跨 zperf / cperf / jsperf / jvmperf，以及更新的套件（每套件的 ID）。

证据相关：jsperf `STATIC-VS-V8`，cperf `STATIC-VS-O2`（保存在仓库之外）。

## 规则回归

存在成对的正/负例，以便我们之后可以问：这个规则是否仍然**有意义**（仍然与速度相关）并且仍然**生效**（在编译器/运行时升级后仍然有效）？

两层：

1. **Lint 测试夹具** — 在每个包的 `*-lint/fixtures/` 下：
   - `bad/` 必须生成规则（正向：气味仍然匹配）。
   - `good/` 必须保持干净（负向：合法/提升/抑制的模式不会误报）。
   - 在工具链更新（Zig、cc、Node、JDK）时重新运行 `make check` / `npm test` / `gradlew test`。夹具通过 ≠ 实时声称。

2. **证据（速度门）** — 在 `packages/*/evidence/` 下：
   - 仅在 `<RULE>.md` + 在 `<RULE>.jsonl` 之前/之后，才保留或升级规则至默认 **`error`**（每个套件保留自己的 `docs/evidence-policy.md`，例如 [cperf](../../packages/cperf/docs/zh-CN/evidence-policy.md)）。
   - 当 **Node/V8**、**gcc/clang** 或 **JDK** 的主要版本变动时，重新运行基准测试；如果比率变化则更新中位数。
   - 剩余语料库计数和去优化/编译日志行计数 **不是** 速度声明，不会升级严重性。

跨套件气味图：[smell-catalog.md](smell-catalog.md)。每条规则的真实覆盖情况（固定装置 + 证据缺口）：[rule-regression.md](rule-regression.md)。
