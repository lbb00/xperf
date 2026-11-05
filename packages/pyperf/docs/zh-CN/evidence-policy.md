# pyperf 证据政策

## 门槛

一条规则只有在同时存在 `evidence/<RULE>.md` 和测量的 `evidence/<RULE>.jsonl` 时才可以是 **`error`**。

## 当前映射

截至2026年10月22日。

| 规则 | 严重性 | 证据 | 异味 |
|------|----------|----------|-------|
| pp-str-plus-hot | **关闭** | 已测量（`pp-str-plus-hot.md` + `pp-str-plus-hot.jsonl`）；保持关闭 | 循环中的字符串 `+=`（G3 OK-成语） |
| pp-list-plus-rebind | 提示 | 测量（`pp-list-plus-rebind.md` + `pp-list-plus-rebind.jsonl`）；保留提示 | 循环中的列表 `+` 重新绑定 |
| pp-print-hot | **关** | 已测量（`pp-print-hot.md` + `pp-print-hot.jsonl`）；保持关闭 | 循环中的 `print(` (G3 CLI) |
| pp-json-hot | 提示 | 测量（`pp-json-hot.md` + `pp-json-hot.jsonl`）；保持提示 | 循环中的 `json.loads` / `dumps` |
| pp-deepcopy-hot | 提示 | 测量 (`pp-deepcopy-hot.md` + `pp-deepcopy-hot.jsonl`); 保持提示 | 循环中的 `deepcopy` |
| pp-open-hot | 提示 | 已测量（`pp-open-hot.md` + `pp-open-hot.jsonl`）；保留提示 | 在循环中 `open`；仅相同路径；非语料库筛选 |
| PP004 | 已移除 | 墓碑 | 见 `evidence/_removed/` |

2026-10-22 规则的已测量 JSONL 存在，但没有被升级：pp-str-plus-hot/pp-print-hot 保持 `off`（G3：CLI 和构建器代码中是 OK-习语），pp-list-plus-rebind 保持 **hint**。PP004 已移除；其墓碑位于 `evidence/_removed/` 下。`pp-regex-compile-in-loop` 和 `pp-datetime-format-in-loop` 已被移除。
