# kotlinperf 语料库目标

大型树木**不会**被转售，并且语料库不会随仓库一起分发：将其克隆到仓库之外的任意本地目录，并将该路径传递给代码检查器。

## 固定目标

| 树 | 链接 | 提交 | 大小 | Lint 范围 |
|------|-----|--------|------|------------|
| kotlinx.coroutines | https://github.com/Kotlin/kotlinx.coroutines.git | `7e0d1b3e9ca83652427ae00dda7d1673f058a743` | ~27M | 整个树 |
| okhttp | https://github.com/square/okhttp.git | `2657315344316ba5bd1292d2fe9ca12636ae2290` | ~15M | 整个代码库（Kotlin 源码） |
| kotlinx.serialization | https://github.com/Kotlin/kotlinx.serialization.git | `4c28c3e33c145da536f1f4a671f70e5eb5b62b9c` | 约13M | 整个树 |

浅克隆（`--depth 1`）。

## 狗粮 (2026-10-21 亚洲/上海)

| 树 | 原始 (`--raw-paths`) | 反向优化后 |
|------|---------------------|-------------------|
| kotlinx.coroutines | **84** (kt-list-add-hot:2 kt-string-plus-hot:6 kt-println-hot:76) | **6** (1/5/0) |
| okhttp | **29** (11/1/17) | **8** (5/0/3) |
| kotlinx.serialization | **4** (2/0/2) | **1** (1/0/0) |

规则顺序：kt-list-add-hot / kt-string-plus-hot / kt-println-hot。

### Reverse-opt（`kotlinperf-lint`）

1. **`--raw-paths`：** 基线开关。
2. **路径跳过：** `test/` `tests/` `androidTest/` `jvmTest/` `commonTest/` `nativeTest/` `benchmarks/` `samples/` `sample/` `examples/` `example/` `docs/`（加上始终跳过 `.git`/`build`/`.gradle`/`vendor`/`fixtures`）。
3. **路径后缀：** `*Test.kt` / `*Tests.kt` / `/src/test/`。
4. **kt-list-add-hot：** 在 reverse-opt 下禁止裸的空 `listOf()`（保留 `mutableListOf` / `arrayListOf` / `ArrayList()`）。
5. **kt-println-hot：** 跳过 KDoc/块注释的延续行（`* … println`）；跳过调试/演示文件名和 `DEBUG` 标记。

### 残差

- 协程：在指导/示例中有一些真正的 `+=` 字符串构建器，它们存在于被跳过的目录之外。
- okhttp：列出热解码路径中的列表分配（信号）。

不要将语料库来源提交到 `packages/kotlinperf`。

## G3 TP/FP 分诊 (2026-10-22 亚洲/上海)

| | r1 sample n=15 | r2 sample n=3 |
|--|----------------|---------------|
| TP | 0% | 0% |
| FP | 40% | 0% |
| OK-idiom | 46.7% | **100%** |
| SKIP-path | 13.3% | 0% |
| **FP+DOC+SKIP** | **53.3%** | **0%** |

**语料准备好了吗？`否`** — r1 噪声 >40%；r2 全部符合习惯用语（懒惰列表 / 罕见类型）。保留规则 **提示**。

### 修复已提交
- kt-string-plus-hot 集合 `+=` 抑制；kt-println-hot 仅限裸 `println`；kt-list-add-hot 延迟/常量 listOf
- 路径跳过：`test-utils/`、`testing-support/`、`rules-integration-tests/`、`okcurl/`
- r2 计数：协程 **1**，okhttp **2**，序列化 **0**

## 重新设计 → 准备语料库（2026-10-22 亚洲/上海）

| 树 | r2 | r3（默认） | 是否准备好语料库？ |
|------|----|---------------|---------------|
| kotlinx.coroutines | 1 | **2** | |
| okhttp | 2 | **9** | |
| kotlinx.serialization | 0 | **1** | |

**判定：语料库可用 `是`。** 样本 n=12：TP 58.3% / 合适成语 41.7% / FP+DOC+跳过 0%。默认设置：kt-list-add-hot–kt-println-hot **关闭**。已移除 KT004（抖动；它覆盖了空列表 + 在有大小提示的循环中添加）。无 G4 升级 / 无虚构 JSONL。
