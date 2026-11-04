# ArkTS 性能指南（v0）

在嵌入式 / HarmonyOS 热路径上减少 GC 抖动与 shape 污染。

> **范围：面向 HarmonyOS 及类似嵌入环境的 ArkTS（类 TypeScript）。** 声称加速的断言会点名本地或真机 bench，或标明为暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。相关 JS 说明见：[jsperf](../../../jsperf/docs/zh-CN/js-performance-guide.md)。

## 如何阅读

1. 尽可能先在真机或忠实运行时上**测量**。
2. 把每一章当作核对清单。
3. 不要假定 V8 数字能迁移到 ArkTS VM——请重测。

## 目录

- [如何阅读](#如何阅读)
- [1. 分配](#1-分配)
- [2. Shape 与 delete](#2-shape-与-delete)
- [3. Bridge / console 噪声](#3-bridge--console-噪声)
- [4. 循环中的查找与 JSON](#4-循环中的查找与-json)
- [Lint 对照](#lint-对照)
