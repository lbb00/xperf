# zp-per-packet-alloc — 热路径分配

## 主张

每个数据包/热点注释的函数，每次调用都会在堆上分配，其成本模型与 **zp-alloc-hot**（在热点循环中分配）相同。

## 证据

没有单独的微基准：重复使用 [`zp-alloc-hot.md`](zp-alloc-hot.md) / [`zp-alloc-hot.jsonl`](../zp-alloc-hot.jsonl)（在这台机器上 GPA 分配+释放比 arena 保留约 **1.4×**；pool/FBA 更大 — 参见 zp-create-destroy-hot/zp-fixed-size-alloc-hot）。

## 与 lint 的对应

`zperf-lint` 的 zp-per-packet-alloc 会在 alloc 出现在 hot-name / `// zperf-lint: hot` / `--hot-fn` 调用链下时触发。在 rules.zig 中，其严重性仍为 **warning**；将测量的符合性视为与 zp-alloc-hot 共享。

## 限制

热度启发式可能会产生误报；当分配是每连接一次而不是每包一次时，请忽略它。
