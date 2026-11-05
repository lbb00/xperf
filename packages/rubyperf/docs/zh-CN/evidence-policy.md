# rubyperf 证据政策

## 门槛

只有当以下两者都存在于 `packages/rubyperf/evidence/` 下时，规则才可被视为 **`error`**：

1. `<RULE>.md` — 声明，如何测量，工具链版本，限制
2. `<RULE>.jsonl` — ≥1 条前后行，包含 `rule`、`case`、`median_ms`、`ops`、`ratio`、`ts`

否则规则保持 **`hint`**（或 **`off`**）。

仅测量的 JSONL 本身不会升级一个规则：被标记的问题还必须在 G3 语料库分类中成立（参见 [corpus.md](corpus.md)）。

## 当前映射

截至2026年10月22日。

| 规则 | 严重性（默认） | 证据 | 异味 |
|------|--------------------|----------|-------|
| rb-string-plus-hot | 关闭 | **是** (`rb-string-plus-hot.md` + `.jsonl`, ~32×) | 循环中的字符串 `+=`（建议使用 `<<`） |
| rb-array-plus-rebind | 关闭 | **是** (`rb-array-plus-rebind.md` + `.jsonl`, ~181×) | 循环中数组 `+` / concat 重新绑定 |
| rb-puts-hot | 关闭 | **是** (`rb-puts-hot.md` + `.jsonl`, ~5×; I/O 依赖于环境) | 循环中的 `puts` / `print` |
| rb-regexp-new-hot | 提示 | 已测量（`rb-regexp-new-hot.md` + `rb-regexp-new-hot.jsonl`）；保持提示 | 循环中的 `Regexp.new`; 未进行语料库分流 |
| rb-json-hot | 提示 | 测量（`rb-json-hot.md` + `rb-json-hot.jsonl`）；保留提示 | 循环中使用 `JSON.parse` / `generate`；未经过语料库筛选 |
| rb-file-read-hot | 提示 | 测量 (`rb-file-read-hot.md` + `rb-file-read-hot.jsonl`)；保持提示 | 循环中使用 `File.read` / `File.open`；仅相同路径；未经过语料排查 |

没有规则是 `错误`：这些比率是真的，但在 G3 OK-idiom 分类后，三个 `off` 规则被降级。`rb-hash-merge-in-loop` 被移除了：在 Ruby 4.0.8 上，字面量构建比 `merge` 慢，并且分配更多。
