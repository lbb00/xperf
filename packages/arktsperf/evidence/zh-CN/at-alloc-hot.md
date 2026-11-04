# at-alloc-hot — 循环中的新建 / 分配 (Node 代理)

**状态:** 已测量 (节点代理)

## 主张

在 **Node/V8** 上，每次迭代新建 `new Uint8Array` 比重用一个缓冲区更慢（代理 ArkTS 循环中分配的异味）。

## 如何测量

- 测试工具：`examples/bench/evidence_at001_at003.js`
- **运行时：node-proxy** — 不是 ArkTS VM / 设备 SoftAP
- warm=3；取 9 的中位数；N=200000

- 原始行: [`at-alloc-hot.jsonl`](../at-alloc-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海 (JSONL `ts` 为 UTC) |
| 运行时 | **node-proxy** |
| node | **v20.19.2** |
| v8 | **11.3.244.8-node.38** |
| 中位数之前 (`new_in_loop`) | ~4.768 毫秒 |
| (`reuse_buffer`) 后的中位数 | ~0.1461 毫秒 |
| **前/后比例** | **~32.6×** |

## 与 lint 的对应

`arktsperf-lint` at-alloc-hot：严重性保持软件包默认（参见证据政策）。JSONL 是 **节点代理**，而不是设备。

## 限制

- 仅代理；ArkTS/ArkRuntime 可能有所不同。
- 默认保持 **关闭**（G3 可接受-习惯用法）；不升级。
