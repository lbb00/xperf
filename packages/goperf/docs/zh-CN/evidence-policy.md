# goperf 证据政策

## 门槛

只有当两者都存在于 `packages/goperf/evidence/` 下时，规则才可以被视为 **`error`**：

1. `<RULE>.md` — 声明、如何测量、`go` 版本 / 标志、限制
2. `<RULE>.jsonl` — ≥1 个前/后行，包含 `rule`、`case`、`median_ns`（或 `median_ms`）、`ops`、`ratio`、`ts`

否则该规则保持 **`hint`**（或在 G3 OK-idiom 降级后为 **`off`**）。

## 当前映射

截至2026年10月22日。

| 规则 | 严重性 | 证据 | 异味 |
|------|----------|----------|-------|
| gp-make-hot | **关** | **是** ~265× | 循环中的 `make`/`new` (G3 可接受的惯用法) |
| gp-string-plus-hot | **关闭** | **是** ~2919× | 循环中的字符串 `+=` (G3 推荐用法) |
| gp-fmt-hot | **关闭** | **是** ~2.8× | 循环中的 `fmt.*printf`（G3 合适用法） |
| gp-append-nil-slice | 提示 | **是** ~12.2× | 在带大小提示的循环中对空切片使用 append |
| gp-defer-hot | 提示 | **是** ~33× | 循环中的 `defer` |
| gp-regexp-compile-hot | 提示 | 测量过的 (`gp-regexp-compile-hot.md` + `gp-regexp-compile-hot.jsonl`); 保持提示 | 循环中的 `regexp.Compile`; 未经过语料库分类 |
| gp-json-marshal-hot | 提示 | 测量过的 (`gp-json-marshal-hot.md` + `gp-json-marshal-hot.jsonl`); 保持提示 | 循环中的 `json.Marshal` / `Unmarshal`; 未进行语料库筛选 |
| gp-reflect-hot | 提示 | 已测量（`gp-reflect-hot.md` + `gp-reflect-hot.jsonl`）；保持提示 | 循环中的 `FieldByName` / `MethodByName` / `reflect.New`；`TypeOf` 不匹配；未经过语料库分类 |
| gp-os-open-hot | 提示 | 已测量（`gp-os-open-hot.md` + `gp-os-open-hot.jsonl`）；保持提示 | 循环中的 `os.Open`；仅同一路径；未进行语料库筛选 |
| gp-time-now-hot | 提示 | 已测量 (`gp-time-now-hot.md` + `gp-time-now-hot.jsonl`); 保持提示 | 循环中的 `time.Now`; 不是 `time.Parse`; 不是语料库分类 |

所有五条规则都有对应的 `.md` + `.jsonl` 测量文件，但没有任何一条会自动升级：gp-append-nil-slice/gp-defer-hot 保持 **提示** 状态，三条降级规则保持 **关闭** 状态（G3 OK-idiom 历史）。可以使用 `--severity <rule>=hint` 重新启用降级规则（例如 `--severity gp-make-hot=hint`）。
