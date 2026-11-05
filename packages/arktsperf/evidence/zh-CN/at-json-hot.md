# at-json-hot — 循环中的 JSON.parse/stringify（Node 代理）

**状态:** 已测量 (节点代理)

## 主张

在循环中解析许多小的 JSON 字符串比对一个数组块执行一次 `JSON.parse` 要慢；在 Node/V8 上，每个项目的 `stringify` 比对一个数组执行一次 stringify 略慢。

## 如何测量

- 测试工具: `examples/bench/evidence_at004_at005.js`
- **运行环境: node-proxy**
- N=20000

- 原始行：[`at-json-hot.jsonl`](../at-json-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| 运行时 | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| 中位数之前 (`parse_in_loop`) | ~8.702 毫秒 |
| (`parse_once_array`) 后的中位数 | ~3.895 毫秒 |
| **前/后比例** | **~2.23×** |
| 循环内字符串化前的中位数 (`stringify_in_loop`) | ~2.985 毫秒 |
| 中位数（`stringify_once` 之后） | ~1.781 毫秒 |
| **前后比例** | **~1.68×** |

## 与 lint 的对应

`arktsperf-lint` 在 json-hot：严重性保持包默认（参见证据政策）。JSONL 是 **Node 代理**，而不是设备。

## 限制

- 适度的比率（约2倍解析，约1.7倍字符串化）。
- 默认保持 **hint**。
