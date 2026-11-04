# Swift 性能指南（v0）

热路径少强制解包，少做平方级字符串 builder。

> **范围：Swift 5.9+。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 0. 范围与方法

1. 先**测量**（Instruments，可用时用 `swift package benchmark`）。
2. 把每一章当核对清单。
3. ARC 与特化会改变成本——工具链升级后请重测。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. Optional 与热路径](#1-optional-与热路径)
- [2. 字符串、集合与打印](#2-字符串集合与打印)
- [3. Formatter、JSON 与正则](#3-formatterjson-与正则)
- [Lint 对照](#lint-对照)
