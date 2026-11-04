# rustperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任意本地目录，并将该路径传递给代码检查器。

## 固定目标

| 树 | 链接 | 提交 | 大小 | Lint 范围 |
|------|-----|--------|------|------------|
| serde | https://github.com/serde-rs/serde.git | `0db9b3b504bcb0a7fa9cf001429869519afd3e9a` | 约3.1M | 全部树 |
| tokio | https://github.com/tokio-rs/tokio.git | `cffdc7601134598cebc45d03af0358dedfcb3ff1` | ~7.9M 稀疏 | `tokio/` 锥 |
| 拍手 | https://github.com/clap-rs/clap.git | `ccc89b83875474399e9d9d70841163f6319d1a41` | ~6.5M | 整个树 |

浅克隆（`--depth 1`）。Tokio 仅对 `tokio/` crate 使用稀疏检出。

## Dogfood + G3（通过 r4 重新设计，2026-10-22 亚洲/上海）

| 树 | 原始 | r1 | r2 | r3-分裂 | r3（rs-alloc-hot 关闭） | **r4（rs-vec-no-capacity/rs-collect-vec-hot）** |
|------|-----|----|----|----------|----------------|----------------------|
| serde | **64** | 43 | 29 | 11 | **0** | **0** |
| tokio | **148** | 15 | 3 | 3 | **0** | **0** |
| 拍手 | **287** | 124 | 78 | 69 | **5** | **6** (rs-collect-vec-hot:2 rs-vec-no-capacity:3 rs-string-plus-in-loop:1) |

规则顺序：rs-alloc-hot / rs-string-plus-in-loop / rs-println-hot / rs-format-rebind-hot / **rs-vec-no-capacity** / **rs-collect-vec-hot**。

**语料库准备就绪: 是** — r4 n=6 全部 **TP**（拍手包裹收集 + 大小为 `Vec::new` + push + 值名 `push_str`）；FP+DOC+SKIP **0%**；在默认设置下 serde/tokio 干净。

### 反向优化（`rustperf-lint`）

1. `-----路径 ' :** 使基线垃圾场无法逆向选择。
2. **Path跳过:** ' tests/` ' tests/`benches/`... + **` tests.rs`** + inline **`# [cfg(test)]'/`# [test]`**.
3. ** " 环头 " :** 真正的 " 仅用于 " / " 同时 " / " 仅用于 " 类型 " 或 " ``` ' a>` " 的X。
4. **rs-alloc-hot 默认 ' off`** - id/`to own'/syn clones 占主导地位;`-severity rs-alloc-hot=hint ' 供审查。
5. **rs-string-plus-in-loop:** / 'push str ' only(**hint**);跳过贝壳/clap complete/mangen;跳过错误/帮助/样式/调试;微秒;跳过`mid string'/`sc names'种子在`command.rs'中。
6. **rs-format-rebind-hot:**`dent = format! (.)' 重新组合再利用(**error**,G4~99×);跳过一发`'``dident''`括号内包装。
7. **rs-println-hot:** 跳过例/demo bins,`cfg!(debug asserments)',`counts.rs'.
8. **rs-vec-no-容量:**空的`Vec ' /`String ' /`vec! ' 然后以**尺寸-inted** 环(**hint**);跳跃衍生箱+冷CLI。
9. **rs-collect-vec-hot:** `collect:<Vec...>在真实的循环内(**hint**);保留文本包装/样式 str;跳过冷的CLI模板/壳。

### 残余（非速度声明）

- r4 仅拍手：wrap-path 收集 + 有大小的冲突/子命令 vec 构建器 + 参数 value-name `push_str` — 均已分类 **TP**。
- rs-vec-no-capacity/rs-collect-vec-hot 保持 **提示**：测量的 G4 比例适中（见 [evidence-policy.md](evidence-policy.md)）。
- 不得编造比例。

不要将语料库来源提交到 `packages/rustperf`。

## 2026-10-23 — 新提示规则，未分类

下面的 slug 是 **提示**。它们有配对的固定装置和待处理的证据备注。它们 **没有** JSONL，并且 **没有** 经过 G2/G3。2026-10-22 准备语料库的裁决不涵盖它们。
