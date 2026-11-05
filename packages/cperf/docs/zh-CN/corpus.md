# cperf 语料库目标

大型树木**不会**被供应，语料库也不会随仓库一起分发：请将其克隆到仓库之外的任意本地目录，并将该路径传递给代码检查器。使用以下命令进行检查：

```sh
cd packages/cperf/cperf-lint && make
./cperf-lint <corpus-dir>/<name> --format json --no-fail
```

检查器是 **C11**（`cperf-lint`）。之前的 Python 原型已被移除。

## 固定目标

为2026-10-22的重新设计克隆（g3f）。

| 树 | 提交 | 大小 | Lint g3c → g3f（默认） |
|------|--------|------|--------------------------|
| **quickjs** | `7d1c13c` 浅 | 7.8M | **0 → 2** cp-strlen-in-cond |
| **lua** | `8cb93ba` shallow | 2.7M | **0 → 0** |
| **gcc** (sparse) | `152e0cc` | 176M | **5 → 7** (cp-strlen-in-cond:2 cp-alloc-hot:5) |
| **sqlite** | `0498915` sparse | 14M | **0 → 0** |

路径跳过未更改的部分 (r3 + G3)。新：cp-strlen-in-cond strlen-in-cond; cp-strcat-hot strcat-in-loop (关闭)。

## 是否 corpus-ready？

**是** — 重新设计后的 G3 2026-10-22（亚洲/上海）。默认残差 **9**
（cp-strlen-in-cond×4 TP + cp-alloc-hot×5，1 TP / 4 OK-习语）。FP+DOC+SKIP **0%**。来自 **cp-strlen-in-cond** 的真实 TP（循环条件中的 `strlen`）。

cp-alloc-hot/cp-realloc-grow-one 保持 **错误** (G4 JSONL)。 cp-printf-hot/cp-strcat-hot 默认 **关闭**。 cp-strlen-in-cond 默认 **提示**。

## 主要

| Tree | Status |
|------|--------|
| quickjs | **完成** (2× cp-strlen-in-cond TP) |
| gcc sparse | **完成** (cp-strlen-in-cond TP + cp-alloc-hot 混合) |
| sqlite | **完成**（默认情况下清除） |
| V8 | 延迟的 (C++ / clang AST) |

## 次要

| Tree | Status |
|------|--------|
| lua | **完成**（清理）|
| redis / libuv / musl | 后期 |

## 库存

```text
<corpus-dir>/
  quickjs/
  lua/
  gcc/            # sparse
  sqlite/         # sparse src/
```

不要将语料来源提交到 `packages/cperf`。

## 2026-10-23 — 新提示规则，未分类

`cp-sprintf-hot`、`cp-fopen-hot`、`cp-gettime-hot` 和 `cp-wide-bool-flags` 是**提示**。每个都有 JSONL 微基准，并且尚未经过 G2/G3。`cp-regex-hot` 是**提示**，并且有 JSONL（约 9.7×）。上述这些 slug 都不属于 2026-10-22 的语料库准备判定。
