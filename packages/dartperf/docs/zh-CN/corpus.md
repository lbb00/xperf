# dartperf 语料库目标

大型树木**不会**被供应，语料库也不会随仓库一起分发：将其克隆到仓库之外的任何本地目录，并将该路径传递给代码检查工具。
使用以下方式进行检查：

```sh
export PATH="$HOME/dart-sdk/bin:$PATH"
export PATH="$HOME/dart-sdk/bin:$PATH"
cd packages/dartperf/dartperf-lint && dart pub get
cd packages/dartperf/dartperf-lint && dart pub get
dart run bin/dartperf_lint.dart <corpus-dir>/<name> --format json --no-fail
dart run bin/dartperf_lint.dart <corpus-dir>/<name> --format json --no-fail
```

检查器是 **Dart** (`dartperf-lint`)。规则 dt-list-add-empty–dt-growable-add-empty。

## 固定目标

克隆于 2026-10-21（亚洲/上海），r1。

| 树 | 提交 | 大小 | Lint (基线 → r1) |
|------|--------|------|----------------------|
| **bloc** | `b9be1e2` 浅拷贝 `https://github.com/felangel/bloc.git` | 64M | **10 → 3** (dt-list-add-empty:3) |
| **dio** | `f1bef46` 浅克隆 `https://github.com/cfug/dio.git` | 9.6M | **19 → 5** (dt-list-add-empty:5) |
| **http** | `1217181` 浅拷贝 `https://github.com/dart-lang/http.git` | 8.8M | **29 → 4** (dt-list-add-empty:4) |

路径跳过（r1 reverse-opt）：`test/`、`tests/`、`example/`、`examples/`、`example_dart/`、`example_flutter/`、`scripts/`、`benchmark(s)/`、`integration_test/`、`fixtures/`、`docs/`，以及以 `*_test.dart` 结尾的文件和以 `_tests` 结尾或包含 `conformance_test` 的目录。

dt-list-add-empty：跳过 StreamController / Sink / `*C.add`（队列/流）模式。

剩余（保留作为信号）：在 bloc LSP 辅助工具中的生产 `List.add`，dio form_data / 适配器，http2 帧/流队列。

## 库存

```text
<corpus-dir>/
<corpus-dir>/
  bloc/
  bloc/
  dio/
  dio/
  http/
  http/
```

不要将语料库来源提交到 `packages/dartperf`。

## G3 TP/FP 分诊（2026-10-22 亚洲/上海）

| | r1 n=12 | r2 n=7 |
|--|---------|--------|
| TP | 0% | 0% |
| FP | 33.3% | 0% |
| OK-idiom | 66.7% | **100%** |
| **FP+DOC+SKIP** | **33.3%** | **0%** |

**准备好语料库？`否`** — BytesBuilder/Headers/Set FPs 已修复；残留是故意的列表收集。保持 dt-list-add-empty **提示**。

### 修复已完成
- 非列表 `.add` 白名单；`??= []` 不再触发 growAssign
- r2 计数：bloc **3**，dio **2**，http **2**

## 重新设计 → 准备语料库（2026-10-22 亚洲/上海）

| 树 | r2 | r3（默认） | 是否准备好语料库？ |
|------|----|---------------|---------------|
| bloc | 3 | **0** | |
| dio | 2 | **0** | |
| http | 2 | **1** | |

**裁定：语料库可用 `是`。** 示例 n=1：TP 100% / FP+DOC+SKIP 0%。默认设置：dt-list-add-empty–dt-print-hot **关闭**；**dt-growable-add-empty** **提示**。检查工具为 Dart (`dartperf-lint`)。
