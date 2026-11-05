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

