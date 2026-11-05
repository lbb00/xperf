# Swift 性能指南（v0）

热路径少强制解包，少做平方级字符串 builder。

> **范围：Swift 5.9+。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（Instruments；可用时用 `swift package benchmark`）。ARC 与特化会改变成本——工具链升级后请重测。

## 目录

- [1. Optional 与热路径](#1-optional-与热路径)
- [2. 字符串、集合与打印](#2-字符串集合与打印)
- [3. Formatter、JSON 与正则](#3-formatterjson-与正则)
- [Lint 对照](#lint-对照)

