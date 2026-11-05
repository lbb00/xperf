# at-includes-hot — 循环中的 includes/indexOf (Node 代理)

**状态:** 已测量 (节点代理)

## 主张

`Array.includes` 在热循环中对 256 条目的列表的速度远慢于 Node/V8 上的 `Set.has`（约 **29 倍**）。短字母表的 `String.indexOf` 与 `Map.get` 相比约为 **0.95 倍**（Map 常常落后）；一个稠密的 **查找表（LUT）** 却能获胜（L=64 时约 3 倍）。Lint 消息（2026-10-22）：Array→Set；String.indexOf→LUT — 对于短的查找内容 **不要** 使用 Map。

## 如何测量

- 测试平台：`examples/bench/evidence_at004_at005.js`
- 深入研究（LUT 分支）：独立脚本，不随本仓库分发
- **运行时：node-proxy** — 不是 ArkTS VM
- 配对：includes→Set (N=5e4); indexOf→Map (N=2e5, 字母长度 64); 深入研究中的 LUT 分支

- 原始行: [`at-includes-hot.jsonl`](../at-includes-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| 运行时 | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| 中值之前 (`includes_loop`) | ~13.37 毫秒 |
| (`set_has`) 后的中位数 | ~0.4637 毫秒 |
| **前/后比例** | **~28.8×** |
| 中位数之前 (`indexOf_loop`) | ~1.954 毫秒 |
| (`map_lookup`) 之后的中位数 | ~2.056 毫秒 |
| **前/后比例** | **~0.951×** |

## 与 lint 的对应

`arktsperf-lint` at-includes-hot：严重性保持为 **提示**。JSONL 是 **节点代理**，不是设备——单独无法升级。夹具 `arktsperf-lint/fixtures/good/at-includes-hot_string_lut.ts` 记录了字符串路径。

## 限制

- 主要结论包括→Set。indexOf→Map 在短字母表上没有优势；更推荐使用查找表（LUT）。
- 默认保持 **hint**；单独使用 Node 代理不会升级为错误。

## 降落 2026-10-22

匹配器消息缩小；已添加良好固定装置的查找表。严重性保持不变。

## 内存 (2026-10-22，node-proxy)

`out` 数组的 `heapUsed` 增量约为 1.25–1.43 MiB；仅 Set(256) 约为 **184 KiB**。问题出在 CPU（包括 → Set），而不是 RAM 减少。[`at-includes-hot.mem.jsonl`](../at-includes-hot.mem.jsonl)。
