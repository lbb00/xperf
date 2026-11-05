# rustperf 证据政策

## 门槛

只有当以下两者都存在于 `packages/rustperf/evidence/` 下时，规则才可被视为 **`error`**：

1. `<RULE>.md` — 声明，如何测量，工具链版本，限制
2. `<RULE>.jsonl` — ≥1 条前/后行，包含 `rule`、`case`、`median_ms`、`ops`、`ratio`、`ts`

否则规则保持 **`hint`**。

仅仅使用 JSONL 不够：只有当 **标记的气味** 本身显示出较大且稳定的速度提升时才升级（如 rs-format-rebind-hot 所示）。同时命中约 ~1× 均摊模式的混合检测器保持 **hint**。

## 当前映射

截至2026年10月22日。

| 规则 | 严重性（默认） | 证据 | 异味 |
|------|--------------------|----------|-------|
| rs-alloc-hot | 关闭 | **是** (`rs-alloc-hot.md` + `rs-alloc-hot.jsonl`) | 循环中的分配/克隆 — Vec::new ~2.7× / fixture 克隆 ~1.1× / to_string ~1.7×；保持 **关闭**（G3 OK-惯用法；没有窄分支导致升级）；使用 `--severity rs-alloc-hot=hint` 进行查看 |
| rs-println-hot | 提示 | **是** (`rs-println-hot.md` + `rs-println-hot.jsonl`) | 循环中的 println! / eprintln! (~12.6× 缓冲 vs 每行；I/O，依赖环境) |
| rs-format-rebind-hot | **错误** | **是** (`rs-format-rebind-hot.md` + `rs-format-rebind-hot.jsonl`，来自 rs-string-plus-in-loop G4 格式的别名！配对) | `format!` 在循环中重新绑定 accum（约 99 倍于 `write!`）；跳过花括号包裹 |
| rs-collect-vec-hot | 提示 | **是** (`rs-collect-vec-hot.md` + `.jsonl`) | 循环中 collect::<Vec> (~1.8×) |
| rs-map-new-hot | 提示 | 测量过的 (`rs-map-new-hot.md` + `rs-map-new-hot.jsonl`); 保持提示 | 循环中的 `HashMap::new`; 两次安静运行约 1.5 倍; 未经过语料库分类 |
| rs-regex-new-hot | 提示 | 已测量（`rs-regex-new-hot.md` + `rs-regex-new-hot.jsonl`）；保持提示 | 循环中的 `Regex::new`；未进行语料库分类 |
| rs-file-open-hot | 提示 | 已测量 (`rs-file-open-hot.md` + `rs-file-open-hot.jsonl`); 保持提示 | 循环中的 `File::open`; 仅相同路径; 未经过语料库筛选 |
| rs-clock-hot | 提示 | 测量 (`rs-clock-hot.md` + `rs-clock-hot.jsonl`); 保持提示 | 循环中的 `Instant::now`; 未经语料库分类 |

rs-alloc-hot G4 2026-10-22：仅测得适度的收益；**不要**大规模升级（OK-idiom 支配 G3）。`rs-string-plus-in-loop` 在大填充保持约 1× 后被移除。Hot `s = format!("{s}…")` 保持在 rs-format-rebind-hot (**错误**)。`rs-vec-no-capacity` 在大填充保持约 1× 后被移除。
