# ArkTS 性能指南（v0）

在嵌入式 / HarmonyOS 热路径上减少 GC 抖动与 shape 污染。

> **范围：面向 HarmonyOS 及同类嵌入环境的 ArkTS（类 TypeScript）。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。 相关 JS 说明见 [jsperf](../../../jsperf/docs/zh-CN/js-performance-guide.md)。

能在真机或等价运行时上先画像更好（`DevEco` profiler、简单计时）。不要默认 Node / Chrome 的 V8 层级建议成立。

## 目录

- [1. 分配](#1-分配)
- [2. Shape 与 delete](#2-shape-与-delete)
- [3. Bridge / console 噪声](#3-bridge--console-噪声)
- [4. 循环中的查找与 JSON](#4-循环中的查找与-json)
- [Lint 对照](#lint-对照)

## 1. 分配

紧密的 UI 或动画循环里的对象 / 数组字面量与 `new` 会加重 GC。画像显示有压力时，复用缓冲区。

Lint: `at-alloc-hot`（默认 off）
## 2. Shape 与 delete

`delete` 与混杂的属性 shape 会走多态路径；更稳妥的是稳定对象布局（与 V8 hidden class 同一思路——请在 ArkTS 上**重测**）。

对 `delete` 与 `Map.delete` 的 Node 代理约 1×，因此没有对应 lint。在 ArkTS VM 上重测后再考虑新增。
## 3. Bridge / console 噪声

热路径上的 `console.log` 以及频繁的同步跨语言 / worker bridge 调用会拖帧。请门控调试 I/O。

Lint: `at-console-hot`（默认 off）
## 4. 循环中的查找与 JSON

热循环里对列表做 `Array.includes` / `indexOf` 是每次迭代线性扫描；先建一次 `Set` 再用 `has`。短字符串场景下，稠密查找表往往优于 `Map`（短 haystack 上 `Map` 常更慢）。在循环里反复 parse/stringify 许多小 JSON 会重复分配与解析；应解析一整块数组，或复用缓冲区。

Lint: `at-includes-hot`, `at-json-hot`（both 默认 hint）. Their JSONL evidence is a Node proxy, not an ArkTS VM, so it cannot raise severity on its own.
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| at-alloc-hot | 循环内分配类写法 | off |
| at-console-hot | 循环内 console / bridge 噪声 | off |
| at-includes-hot | 循环内 `includes` / `indexOf` | hint |
| at-json-hot | 循环内 `JSON.parse` / `stringify` | hint |

仅在 `evidence/at-*.jsonl` 之上再叠加真机或 ArkTS-VM bench 时才升级（见 [evidence-policy.md](evidence-policy.md)）。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
- [jsperf 指南](../../../jsperf/docs/zh-CN/js-performance-guide.md)（相关，但不相同）
