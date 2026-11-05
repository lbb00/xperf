# cppperf 证据政策

## 门槛

只有当以下两者都存在于 `packages/cppperf/evidence/` 下时，规则才可被视为 **`error`**：

1. `<slug>.md` — 声明，如何测量，工具链版本，限制
2. `<slug>.jsonl` — ≥1 条前/后行，包含 `rule`、`case`、`median_ms`、`ops`、`ratio`、`ts`

否则规则保持 **`hint`**。

## 当前映射

截至2026-10-23。2026-10-22的语料库裁决不包括在该日期之后添加的 slug。

| 规则 | 严重性 | 证据 | 异味 |
|------|----------|----------|-------|
| cx-regex-ctor-hot | **提示** | 已测量（`cx-regex-ctor-hot.md` + `cx-regex-ctor-hot.jsonl`）；保持提示 | 在循环中构造的 `std::regex`；未经过语料排查 |
| cx-endl-hot | **提示** | 已测量（`cx-endl-hot.md` + `cx-endl-hot.jsonl`）；保持提示 | 循环中的 `endl` 刷新；未进行语料库筛选 |
| cx-clock-hot | **提示** | 已测量 (`cx-clock-hot.md` + `cx-clock-hot.jsonl`); 保持提示 | 循环中的时钟采样；约 147 倍于单次采样；未经过语料库筛选 |
| cx-ifstream-hot | **提示** | 测量（`cx-ifstream-hot.md` + `cx-ifstream-hot.jsonl`）；保持提示 | 循环中打开的 `ifstream`；仅相同路径；未经过语料库筛选 |
| cx-const-by-value | **提示** | 测量值（`cx-const-by-value.md` + `cx-const-by-value.jsonl`）；保持提示 | 按值传递的 `const` 字符串或向量（参数或范围 for）；当复制分配时大约增加 15–21 倍；短字符串和完全扫描时保持接近 1×；未经过语料库分类 |
| cx-vector-bool | **提示** | 测量过的 (`cx-vector-bool.md` + `cx-vector-bool.jsonl`); 保留提示 | 压缩布尔容器；迭代器遍历约为字节向量的 12 倍；索引约为 4.2 倍，推入约为 6.9 倍；字节数更小；未进行语料库筛选 |
| CX001 | **已移除** | 墓碑 | 见 `evidence/_removed/` |
| CX003 | **已移除** | 墓碑 | 见 `evidence/_removed/` |
| CX004 | **已移除** | 墓碑 | 见 `evidence/_removed/` |

活动 slug 计数：**6**（`cx-regex-ctor-hot`、`cx-endl-hot`、`cx-clock-hot`、`cx-ifstream-hot`、`cx-const-by-value`、`cx-vector-bool`）。`cx-string-append-unreserved` 在记录的 `-O2` 运行维持约 1.09× 后被移除。测量后的 JSONL 保持 **提示**。`cx-sstream-in-loop` 在公平的 `-O2` 运行维持约 1.2× 后被移除。抖动移除：CX001/CX003/CX004。仅测量 JSONL 并不会将规则升级超过 **提示**。一个未知的 slug 保持 **提示**。
