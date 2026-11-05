# objcperf

> **范围说明：** **objcperf** 是 **Objective-C**（MRC/ARC；循环里的 `NSString` 拼接与 `NSLog`）。与姊妹 kit [swiftperf](../../swiftperf/) 不同。在 Linux 上检查器是对 `.m`/`.h` 的 **C 行窗扫描器**（clang 构建该工具）；lint 不需要完整的 Apple 运行时。

Objective-C 性能笔记、小示例，以及 `objcperf-lint`。

属于 [XPerf](../../../zh-CN/README.md)。共享文档：[docs/README.md](../../../docs/zh-CN/README.md)。针对 2026-10-22 规则集 **corpus-ready**。oc-nsstring-append-hot / oc-nslog-hot 默认 **off**（已测，未升级）。日期格式化器、JSON 与正则 hint 尚待测量，不在该裁决内。两条规则已移除（墓碑，从未拿到 slug）。指南 v0。

## 目录

- [英文指南（v0）](../docs/zh-CN/objc-performance-guide.md) — 来自 `docs/guide-src/`
- [`objcperf-lint`](../objcperf-lint/README.md) — 两条实测规则 **off**；三条 hint 规则待测；两条规则已移除（墓碑，从未拿到 slug）
- [语料固定目标](../docs/zh-CN/corpus.md)

## 关注点

预分配 `NSMutableArray`，避免循环里的 `stringByAppendingString`（优先 `NSMutableString`），热循环里不要放 `NSLog`。

## 运行 lint

```sh
cd packages/objcperf/objcperf-lint && make
./objcperf-lint path/to/sources
bash ../scripts/smoke-lint.sh
bash ../scripts/self-lint.sh
```

仅 **error** 级发现时退出 `1`（hint 退出 `0`，除非 `--strict-hints`）。

## 布局

```text
docs/guide-src/   章节源
docs/             组装后的指南 + corpus.md + evidence-policy.md
evidence/         两条实测规则（均 off）；三条待定 hint 笔记；OC001/OC004 墓碑
examples/         小演示
objcperf-lint/    检查器 + 夹具
scripts/          smoke-lint.sh, self-lint.sh
```
