# zperf 证据

`zperf-lint` 规则的墙钟门前/门后。政策：[../docs/evidence-policy.md](../../docs/zh-CN/evidence-policy.md)。

## 当前 (md + jsonl)

[zp-alloc-hot](zp-alloc-hot.md), [zp-append-without-reserve](zp-append-without-reserve.md), [zp-page-allocator-small](zp-page-allocator-small.md), [zp-print-hot](zp-print-hot.md), [zp-unbuffered-io](zp-unbuffered-io.md), [zp-aos-single-field](zp-aos-single-field.md), [zp-bool-array](zp-bool-array.md), [zp-static-string-map](zp-static-string-map.md), [zp-runtime-div-hot](zp-runtime-div-hot.md), [zp-queue-ordered-remove](zp-queue-ordered-remove.md), [zp-shift-on-read](zp-shift-on-read.md), **[zp-per-packet-alloc](zp-per-packet-alloc.md)**（共享 zp-alloc-hot 数据），[zp-invariant-float-div](zp-invariant-float-div.md), [zp-map-put-without-ensure](zp-map-put-without-ensure.md), [zp-arena-reset-free-all](zp-arena-reset-free-all.md), [zp-create-destroy-hot](zp-create-destroy-hot.md), [zp-fixed-size-alloc-hot](zp-fixed-size-alloc-hot.md)

## 待处理措施（仅限 md 占位符 — 无 jsonl）

- **[zp-broad-runtime-safety](zp-broad-runtime-safety.md)** — ReleaseSafe 范围内关闭安全性
- **[zp-packable-bools](zp-packable-bools.md) / [zp-usize-index-field](zp-usize-index-field.md) / [zp-optional-scalar-field](zp-optional-scalar-field.md)** — 在此传递中利用布局密度而不使用已提交的带宽

## 不适用（仅限静态 / 正确性 / 静态大小）——仅 MD 存根

- **[zp-debug-allocator](zp-debug-allocator.md)** 构建模式下的 GPA 选择
- **[zp-missing-free](zp-missing-free.md)** 缺失的释放
- **[zp-catch-unreachable-alloc](zp-catch-unreachable-alloc.md)** 捕获不可达的分配
- **[zp-oversized-enum-tag](zp-oversized-enum-tag.md)** 超大的枚举标签（大小/ABI）
- **[zp-catch-unreachable-io](zp-catch-unreachable-io.md)** 捕获不可达的 I/O

## 不确定（仅医学存根 — 无 jsonl）

- **[zp-large-struct-by-value](zp-large-struct-by-value.md)** large-struct-by-value — ReleaseFast 省略了微基准测试；不要伪造 JSONL

测试工具：`../examples/bench/evidence_fill.zig` · 重新生成：`../scripts/regen-evidence.sh`
