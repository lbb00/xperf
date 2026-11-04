# zp-packable-bools — 待定措施

## 状态

**待处理措施** — 尚无 `evidence/zp-packable-bools.jsonl`。

## 原因

可打包的布尔值/位打包是一种**布局密度**声明。此优化并没有实现一个带宽或缓存敏感的测试工具，能够真实展示仅通过打包带来的时钟时间影响。

## 为什么没有 JSONL

没有专用内存流量基准的密度不是速度门。

## 解阻条件

对大型工作集进行 SoA / bitset 风格的遍历（或已知良好的 zp-bool-array 风格 bitset 框架，限定在 zp-packable-bools 的模式下），然后是 JSONL。在此之前，该规则保持**关闭**状态。
