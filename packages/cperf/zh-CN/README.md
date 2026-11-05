# cperf

C11/C17 性能笔记、小示例，以及用 **C11** 编写的 `cperf-lint`。在相同模式适用的地方，会出现简要的 C++ 备注。

[XPerf](../../../zh-CN/README.md) 的一部分。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。严重性预设。指南 v0。墙钟证据门 `cp-alloc-hot`、`cp-realloc-grow-one` 和 `cp-printf-hot`；`cp-strlen-in-cond`（提示）和 `cp-strcat-hot`（关闭）尚无。`cp-sprintf-hot`、`cp-fopen-hot`、`cp-gettime-hot` 和 `cp-wide-bool-flags` 是带 JSONL 的提示，并且未进行语料库分流。`cp-regex-hot` 是带 JSONL 的提示（约 9.7×），并且未进行语料库分流。语料库 r1–r3 仍为 lint dogfood。

## 目录

- [英文指南 (v0)](../docs/zh-CN/c-performance-guide.md) — 来自 `docs/guide-src/`
- [`cperf-lint`](../cperf-lint/README.md) — **C11** 检查器
- [语料库固定](../docs/zh-CN/corpus.md)

## 焦点

竞技场/池，容量翻倍，strlen 条件内（cp-strlen-in-cond），热点路径 stdio（cp-printf-hot），循环中的 strcat（cp-strcat-hot），格式化写入，文件打开，循环中的时钟采样，以及真实的测量记录。没有本地基准或引用的说法仍是暂定；语料计数是 lint 内部测试用的。

## 构建示例

```sh
cc -std=c17 -O2 -o /tmp/m01 examples/m01_arena.c && /tmp/m01
cc -std=c17 -O2 -o /tmp/p01 examples/p01_soa.c && /tmp/p01
```

## 运行 lint

```sh
cd packages/cperf/cperf-lint
make
./cperf-lint path/to/sources --preset app          # alloc/realloc=error; strlen, later hints, and cp-regex-hot=hint; printf/strcat=off
./cperf-lint path/to/sources --preset all          # every rule error
./cperf-lint path/to/sources --severity cp-printf-hot=off
make self-lint   # dogfood: lint src/ + include/, must be clean
make test        # fixtures + severity smoke + self-lint
```

从包根目录：`bash scripts/smoke-lint.sh`。

当存在**错误**级别的发现时，退出代码为 `1`（提示会打印，但除非使用 `--strict-hints`，否则退出 `0`）。使用/IO 错误时，退出代码为 `2`。

## 布局

```text
docs/guide-src/   chapter sources (00_head … 04_hot_calls, 99_tail)
docs/             assembled guide + corpus.md + evidence-policy.md
evidence/         wall-clock gates: cp-alloc-hot, cp-realloc-grow-one, cp-printf-hot (*.md + *.jsonl)
examples/         tiny C demos + bench/ harnesses
cperf-lint/       C11 checker (src/, include/, Makefile) + fixtures
scripts/          regen-evidence-*.sh, run-static-vs-o2.sh
```
