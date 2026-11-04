# vt-unsafe-threadlocal-pool — 未发布（以指南为先）

## 状态

**未发货 / 仅指南** — 没有 `evidence/vt-unsafe-threadlocal-pool.jsonl`。不要自行创建。规则 **不在** `Rule.RULES` 中，并且没有 `bad/`/`good/` 的 lint 配置。

## 原因

选项 B：保留作为教学材料，直到反向选择/FP 审查证明可以发布。导向夹具存放位置如下：

- `jvmperf-lint/fixtures/guide/vt-unsafe-threadlocal-pool_bad.java` / `vt-unsafe-threadlocal-pool_good.java`
- `jvmperf-lint/fixtures/guide/vt-unsafe-threadlocal-pool_bad.kt` / `vt-unsafe-threadlocal-pool_good.kt`
- `jvmperf-lint/fixtures/guide/README.md`

## 为什么没有 JSONL

没有发货规则 → 没有速度门。待处理/不适用的证据存根适用于**已发货**的ID；此文件仅记录故意的缺失。

## 解阻条件

只有在导盲犬食品 + 反向优化显示低假阳性后才发货；然后添加 `bad/`/`good/`，连接 `Rule.RULES`，并在升级严重性之前进行测量。
