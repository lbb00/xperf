# objcperf 语料库目标

大型树木**不是**经过供应的，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查器。

## 固定目标

| 树 | 链接 | 提交 | 大小 | Lint 范围 |
|------|-----|--------|------|------------|
| AFNetworking | https://github.com/AFNetworking/AFNetworking.git | `d9f589cc2c1fe9d55eb5eea00558010afea7a41e` | 约3.5M | 整个仓库 |
| SDWebImage | https://github.com/SDWebImage/SDWebImage.git | `c3ad5e1a9bf55c9b76d4c362430b5fcded96c502` | ~45M | 整个仓库 |
| fmdb | https://github.com/ccgus/fmdb.git | `d3abf748a2788471535993286603322ccdd02c3d` | ~1.1M | 整棵树 |

浅克隆（`--depth 1`）。纯 ObjC 树（没有仅限 Swift 的 pods）。

## 狗粮 (2026-10-21 亚洲/上海)

| 树 | 原始 (`--raw-paths`) | 反向优化后 |
|------|---------------------|-------------------|
| AFNetworking | **7** (OC001:7) | **4** (4/0/0) |
| SDWebImage | **9** (8/0/1) | **1** (1/0/0) |
| fmdb | **28** (1/1/26) | **10** (1/1/8) |

规则顺序：OC001 / oc-nsstring-append-hot / oc-nslog-hot。

### 反向优化（`objcperf-lint`）

1. **`--raw-paths`：** 基线开关。
2. **路径跳过：** `Tests/` `tests/` `Test/` `Example/` `Examples/` `Demo/` `sample/` `Sample/` `docs/` `Specs/` `benchmarks/` （另外总是跳过 `.git`/`Pods`/`Carthage`/`vendor`/`fixtures`）。
3. **OC001：** 仅匹配 `addObject:` / `addObject]` — **不**匹配 `addObjectsFromArray`（子字符串误报）。
4. **oc-nslog-hot：** 跳过 `DEBUG`/`NDEBUG` 令牌以及 Debug/Logger 路径名。

### 残差

- AFNetworking 查询/证书集合 `addObject:` 无附近容量（比较真实的情况）。
- fmdb `FMDatabase.m` 在绑定/关闭路径中的诊断 `NSLog`（库调试；保留）。
- fmdb 中一个 `stringByAppendingString` 版本归一化。

不要将语料库来源提交到 `packages/objcperf`。

## G3 TP/FP 分诊 (2026-10-22 亚洲/上海)

| | r1 n=15 | r2 n=9 |
|--|---------|--------|
| TP | 13.3% | 22.2% |
| FP | 20.0% | 0% |
| OK-idiom | 66.7% | **77.8%** |
| **FP+DOC+SKIP** | **20.0%** | **0%** |

**准备好语料库了吗？`否`** — 修复 `setWithCapacity` 漏报后，OK-idiom 占主导。轻微的真阳性仍然存在（查询/证书数组没有容量）。保留 **提示**。

### 修复已完成
- OC001 识别 `setWithCapacity` / `dictionaryWithCapacity`
- oc-nslog-hot 跳过附近的 `DEBUG` / `_traceExecution`
- r2 计数：AFNetworking **2**，SDWebImage **1**，fmdb **6**

## 重新设计 → 准备语料库（2026-10-22 亚洲/上海）

| 树 | r2 | r3（默认） | 准备好语料库？ |
|------|----|---------------|---------------|
| AFNetworking | 2 | **2** | |
| SDWebImage | 1 | **1** | |
| fmdb | 6 | **0** | |

**判决：语料库就绪 `是`。** 样本 n=3：TP 66.7% / OK-成语 33.3% / FP+DOC+跳过 0%。当时的默认设置：OC001–oc-nslog-hot **关闭**；**OC004** **提示**。启发式路径 — G0–G3 不需要 Apple SDK（在这台机器上 OC001 G4 仍然在没有 `Foundation.h` 的情况下被阻止）。

OC001 和 OC004 随后被移除（见 [rule-ids.md](rule-ids.md)）。在那时，lint 仅包含 `oc-nsstring-append-hot` 和 `oc-nslog-hot`，两者默认均为**关闭**。

## 2026-10-23 — 新提示规则，未分类

下面的 slug 是 **提示**。每一个都有一个 JSONL 微基准测试，并且尚未经过 G2/G3。2026-10-22 可用于语料库的裁定不包括它们。

- `oc-dateformatter-hot`，`oc-json-hot`，`oc-regex-hot`
