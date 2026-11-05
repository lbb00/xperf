# csharpperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任意本地目录，并将该路径传递给代码检查器。

```sh
cd packages/csharpperf/csharpperf-lint && dotnet run -c Release -- <corpus-dir>/<name> --format json --no-fail
```

检查器：`csharpperf-lint`。规则 cs-list-add-no-capacity–cs-regex-hot。

## 固定目标

克隆的树，r1/after → r2 → r3（重新设计）。提交指针未被记录；重新克隆时请记录提交。

| 树 | 钉 | 绒毛 (之后 → r2 → **r3**) |
|------|-----|------------------------------|
| **Newtonsoft.Json** | 未记录 | **38 → 33 → 3**（cs-regex-hot）|
| **serilog** | 未记录 | **3 → 1 → 0** |
| **Humanizer** | 未记录 | **24 → 3 → 0** |

## G3 TP/FP 分诊（2026-10-22 亚洲/上海）

| 阶段 | n 样本 | 真阳性 | 假阳性+文档+跳过 | 语料库准备好了吗？ |
|-------|----------|----|-------------|----------------|
| after/r1 | 65 | 0% | 21.5% | **no** |
| r2 | 37 | 0% | 0% | **no** (OK-idiom) |
| **r3** (cs-regex-hot) | **3** | **100%** | **0%** | **是** |

r2→r3：降级 cs-list-add-no-capacity–cs-console-hot → **关闭**；添加 **cs-regex-hot**（提示）。没有 G4 JSONL。

## 2026-10-23 — 新提示规则，未分类

这些软体动物是**提示**。它们没有经过 G2/G3。上面的针数总计不包括它们。2026-10-22 可用于语料库的裁定不涵盖它们。

- `cs-linq-materialize-hot`、`cs-format-hot` —— 墙钟时间 JSONL 在磁盘上；默认仍然是提示
- `cs-json-hot` —— 一个固定负载的 JSONL（大约 1500 倍）；可变负载无法提升；仍然是提示
