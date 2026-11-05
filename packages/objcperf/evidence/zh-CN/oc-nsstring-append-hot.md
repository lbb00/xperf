# oc-nsstring-append-hot — NSString 追加 vs NSMutableString

**状态:** 已测量 (gnustep)

## 主张

GNUstep：循环中的 `stringByAppendingFormat` 与 `NSMutableString` ~**569×** 在 N=15000 时。

## 如何测量

- 测试工具：`packages/objcperf/examples/bench/evidence_oc.m`
- 原始行：[`oc-nsstring-append-hot.jsonl`](../oc-nsstring-append-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| runtime | **gnustep** |
| `stringByAppending` 之前的中位数 | ~1236 毫秒 |
| (`mutable_string`) 之后的中位数 | ~2.172 毫秒 |
| **前/后比率** | **~569×** |

## 与 lint 的对应

`objcperf-lint` oc-nsstring-append-hot：默认保持 **`关闭`**。

## 限制

- 绳索时间`弦-弦-弦-弦-弦-弦-弦-弦-弦-弦-弦-弦-弦 ' ;
- 强于GNUstep;苹果运行时间可能有所不同. 默认不发生****。
