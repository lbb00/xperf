# cppperf 语料库目标

大型树木**不会**被供应，语料库也不会随仓库一起分发：将它克隆到仓库之外的任何本地目录，并将该路径传递给代码检查工具。
使用以下命令进行代码检查：

```sh
cd packages/cppperf/cppperf-lint && make
./cppperf-lint <corpus-dir>/<name> --format json --no-fail
```

检查器是 **C++17** (`cppperf-lint`)。活动规则：`cx-regex-ctor-hot`、`cx-endl-hot`、`cx-clock-hot`、`cx-ifstream-hot`、`cx-const-by-value`、`cx-vector-bool`。`cx-string-append-unreserved` 已被移除（约 1.09×）。2026-10-23 添加的规则是提示，并不属于下面的语料库判定。已移除（抖动）：CX001/CX003/CX004。

## 固定目标

克隆于 2026-10-21（亚洲/上海）；lint 计数 r1 → r2 → r3（重新设计）。

| 树 | 提交 | 大小 | Lint（基线 → r1 → r2 → **r3**） |
|------|--------|------|-------------------------------------|
| **json** | `ef3d350` 浅拷贝 `https://github.com/nlohmann/json.git` | 91M | **4 → 0 → 0 → 0** |
| **fmt** | `0fc3163` 浅克隆 `https://github.com/fmtlib/fmt.git` | 4.5M | **49 → 11 → 3 → 0** |
| **spdlog** | `76d4580` 浅拷贝 `https://github.com/gabime/spdlog.git` | 2.3M | **25 → 4 → 1 → 3** (CX004) |

路径跳过：`test/`、`tests/`、`Tests/`、`third_party/`、`thirdparty/`、`benchmarks/`、`benchmark/`、`bench/`、`examples/`、`example/`、`docs/`、`gtest/`、`gmock/`、`doctest/`、`bundled/`，以及现有的 `.git` / `vendor` / `build`。

## G3 TP/FP 分诊 (2026-10-22 亚洲/上海)

| 阶段 | 样本数量 | 真阳性 | 假阳性 | 正确成语 | 假阳性+文档+跳过 | 语料库准备好？ |
|-------|----------|----|----|----------|-------------|----------------|
| r1 | 15 | 0% | 20% | 80% | 20% | **no** |
| r2 | 4 | 0% | 0% | 100% | 0% | **no** (OK-idiom / no TP) |
| **r3** (CX004) | **3** | **100%** | 0% | 0% | **0%** | **yes** |

r2→r3：将 CX001–CX003 降级 → **关闭**；添加 **CX004**（提示）。spdlog 1→**3** 真实 TP。严重性：CX004 **提示**（无 G4 JSONL）。CX001、CX003 和 CX004 在同一天晚些时候在抖动控制下被淘汰（参见 [rule-ids.md](rule-ids.md)）；上面的表格是历史记录。

## 库存

```text
<corpus-dir>/
  json/
  fmt/
  spdlog/
```

不要将语料库来源提交到 `packages/cppperf`。

## 2026-10-23 — 新提示规则，未分类

下面的 slug 是 **提示**。它们尚未经过 G2/G3。2026-10-22 可用于语料库的裁决不涵盖它们。

- `cx-clock-hot` 有 JSONL（约 147× 与仅采样一次相比）并保持提示。
