# jvmperf 语料库目标

## 固定目标

大型树在此包中**不**被供应，也不会随仓库一起发布。将它们克隆到任何本地目录，并将该路径传递给代码检查工具。这些树没有记录提交版本；请在结果旁边标注你扫描时的修订版本。

```sh
export JAVA_HOME=/opt/java/jdk-21.0.12.1+1   # or any JDK 21+
export JAVA_HOME=/opt/java/jdk-21.0.12.1+1   # or any JDK 21+
cd packages/jvmperf/jvmperf-lint && ./gradlew jar
cd packages/jvmperf/jvmperf-lint && ./gradlew jar
LINT=$PWD/bin/jvmperf-lint
LINT=$PWD/bin/jvmperf-lint
$LINT --no-fail -f json -j 4 <path-to-clone>
$LINT --no-fail -f json -j 4 <path-to-clone>
```

检查器是 **Java**（`jvmperf-lint`）。这个工具包中没有 Python。

默认严重性遵循 `Rule.java`：**错误** jp-string-concat-hot、jp-boxed-stream、jp-enum-key-hash-collection、jp-data-copy-hot、jp-baos-tobytearray-copy、jp-hot-payload-copy、jp-client-factory-recreate、jp-string-intern-hot（G4 JSONL）；**提示** jp-value-class-boxing、jp-android-sparse-array、jp-finalize、jp-hot-system-call、jp-bitmap-decode-no-reuse、jp-hot-post-lambda、jp-ui-text-append、jp-non-static-field-updater；其他所有规则均为**关闭**（可通过 `--enable` 选择）。

### 库存

```text
<corpus-dir>/
<corpus-dir>/
  okhttp/ retrofit/ kotlinx-coroutines/ guava/ vertx/ fastjson2/
  okhttp/ retrofit/ kotlinx-coroutines/ guava/ vertx/ fastjson2/
  jetty/          # sparse jetty-core
  jetty/          # sparse jetty-core
  netty/          # sparse buffer + common
  netty/          # sparse buffer + common
```

不要将语料库来源提交到 `packages/jvmperf`。

## 克隆 + G3 (2026-10-22, 亚洲/上海) — r6

| 树 | 范围 | after4 → r5 → **r6** |
|------|-------|---------------------:|
| **okhttp** | 整体 | 48 → 9 → **6** (jp-data-copy-hot) |
| **retrofit** | whole | 6 → 0 → **0** |
| **kotlinx.coroutines** | 全部 | 4 → 0 → **0** |
| **番石榴** | `guava/src` 仅 | 30 → 3 → **1** |
| **vert.x** | whole | 60 → 10 → **1** |
| **fastjson2** | whole | 49 → 12 → **8** |
| **Jetty** | 精简的 `jetty-core` | 267 → 55 → **6** |
| **Netty** | 稀疏 `buffer` + `common` | 24 → 8 → **4** |
| **Total (8 trees)** | | **488 → 97 → 26** |

**G3 分诊:** 本地运行；分诊记录不随同传送。

**语料库准备好：是** — r6 n=26 完整：TP 50%，FP+DOC+SKIP 0%；在 jp-data-copy-hot/jp-hot-payload-copy/jp-finalize 上的真实 TP；每个默认 **错误** 都有 G4 (`evidence/*.md`+`jsonl`)。

### 反向优化

- 路径：`samples?/examples?/recipes?/demos?/snippets?` → `source_group=test`（加上之前的基准/KMP 测试跳过）
- 将几乎所有的 OK 习语 / 无 G4 热启发式降级为 **关闭**（例如 jp-unpresized-collection、jp-hot-heavy-alloc、jp-hot-format-log）
- 保持测量的有效性主干为 **错误**（例如 jp-string-concat-hot、jp-data-copy-hot、jp-hot-payload-copy）
