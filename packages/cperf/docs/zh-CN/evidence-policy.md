# cperf 证据政策

## 门槛

只有当 `packages/cperf/evidence/` 下同时存在以下两项时，cperf 规则才可以被记录/处理为 **`error`**：

1. `<slug>.md` — 说明、如何测量、`cc` 版本/标志、限制
2. `<slug>.jsonl` — ≥1 行前/后数据，字段包括 `rule`、`case`、`median_ms`、`ops`、`ratio`、`ts`，以及 `cc`（编译器和标志；`node` 和 `v8` 保持为空）。可选字段 `role`：`before` = 问题，`after` = 修复。

否则规则最多是 **`hint`**。

拥有 JSONL 是必要的但不充分的：如果测量到的契合度只有部分（在常见形状上进行静态执行而不使用实时时钟成本），保留 **`hint`** 并在 md 中记录负面情况。

## 当前映射

截至2026年10月22日。

| 规则 | 严重程度 | 证据 | 裁决 |
|------|----------|----------|---------|
| cp-alloc-hot | **错误** | [cp-alloc-hot.md](../../evidence/zh-CN/cp-alloc-hot.md) · [cp-alloc-hot.jsonl](../../evidence/cp-alloc-hot.jsonl) | 同意 ~**10.8×** malloc-in-loop 对比 arena |
| cp-realloc-grow-one | **错误** | [cp-realloc-grow-one.md](../../evidence/zh-CN/cp-realloc-grow-one.md) · [cp-realloc-grow-one.jsonl](../../evidence/cp-realloc-grow-one.jsonl) | 同意 ~**12.6×**（伴随 case4 ~3×）；方向明确 |
| cp-printf-hot | **关闭**（默认） | [cp-printf-hot.md](../../evidence/zh-CN/cp-printf-hot.md) · [cp-printf-hot.jsonl](../../evidence/cp-printf-hot.jsonl) | 热 unbuf/buf ~**4.8×** 是；G3 语料库几乎全部 OK-习语/`#if 0` → **关闭**；使用 `--preset all` 或 `--severity cp-printf-hot=hint` |
| cp-strlen-in-cond | **提示** | [cp-strlen-in-cond.md](../../evidence/zh-CN/cp-strlen-in-cond.md) | 当字符串可能变化时约 125×；当 `-O2` 提升时约 0.93×；保留提示 |
| cp-strcat-hot | **关闭**（默认） | [cp-strcat-hot.md](../../evidence/zh-CN/cp-strcat-hot.md) | 比结束指针快约 221 倍；保持关闭（G3） |
| cp-sprintf-hot | **提示** | [cp-sprintf-hot.md](../../evidence/zh-CN/cp-sprintf-hot.md) · [cp-sprintf-hot.jsonl](../../evidence/cp-sprintf-hot.jsonl) | 待定；尚未语料库分类 |
| cp-fopen-hot | **提示** | [cp-fopen-hot.md](../../evidence/zh-CN/cp-fopen-hot.md) · [cp-fopen-hot.jsonl](../../evidence/cp-fopen-hot.jsonl) | 待定；未进行语料库分类 |
| cp-gettime-hot | **提示** | [cp-gettime-hot.md](../../evidence/zh-CN/cp-gettime-hot.md) · [cp-gettime-hot.jsonl](../../evidence/cp-gettime-hot.jsonl) | 待处理；未进行语料库分级；未匹配裸 `time` |
| cp-wide-bool-flags | **提示** | [cp-wide-bool-flags.md](../../evidence/zh-CN/cp-wide-bool-flags.md) · [cp-wide-bool-flags.jsonl](../../evidence/cp-wide-bool-flags.jsonl) | 存在 JSONL；保持提示；未经过语料筛选；四个全角标志，没有位字段 |
| cp-regex-hot | **提示** | [cp-regex-hot.md](../../evidence/zh-CN/cp-regex-hot.md) · [cp-regex-hot.jsonl](../../evidence/cp-regex-hot.jsonl) | 约 9.7×；保持提示；未进行语料库分类；`regexec` 未匹配 |
| cp-alloca-hot | **提示** | [cp-alloca-hot.md](../../evidence/zh-CN/cp-alloca-hot.md) · [cp-alloca-hot.jsonl](../../evidence/cp-alloca-hot.jsonl) | 栈覆盖 1280000 对比 64 字节；墙时钟约 1×；保持提示；未进行语料库分流；VLA 未匹配 |
| cp-struct-by-value | **提示** | [cp-struct-by-value.md](../../evidence/zh-CN/cp-struct-by-value.md) · [cp-struct-by-value.jsonl](../../evidence/cp-struct-by-value.jsonl) | 在 512 字节时跨 TU 约 12.3×；同 TU 约 1×；保持提示；未经过语料库筛选 |

## 再生

```sh
bash packages/cperf/scripts/regen-evidence-cp001.sh
bash packages/cperf/scripts/regen-evidence-cp002.sh
bash packages/cperf/scripts/regen-evidence-cp003.sh
# optional correlation suite → examples/bench/build/static-vs-o2/
bash packages/cperf/scripts/run-static-vs-o2.sh
```

如果比例有明显变化，请更新匹配的 `<slug>.md` 中值。

## CLI 预设

默认 `--preset app`（和 `engine`）：**cp-alloc-hot=error**、**cp-realloc-grow-one=error**、**cp-strlen-in-cond=hint**、**cp-sprintf-hot=hint**、**cp-fopen-hot=hint**、**cp-gettime-hot=hint**、**cp-wide-bool-flags=hint**、**cp-regex-hot=hint**、**cp-alloca-hot=hint**、**cp-struct-by-value=hint**、**cp-printf-hot=off** 和 **cp-strcat-hot=off**。关闭的规则是 G3 2026-10-22 降级。提示未经过语料库分级。`cp-regex-hot`、`cp-alloca-hot` 和 `cp-struct-by-value` 有 JSONL 并保持提示状态。未知的 slug 保持 **hint**。

`--preset all` 会将每条规则提升为 dogfood 的错误级别。可覆盖：`--severity RULE=error|hint|off`。
