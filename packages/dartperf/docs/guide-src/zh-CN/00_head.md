# Dart 性能指南（v0）

少做 list 扩容，少产生字符串 `+` 临时对象，让热循环更安静。

> **范围：Dart 3.x（VM / Flutter）。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 如何阅读

1. 先**测量**（`benchmark_harness`、DevTools CPU profiler）。
2. 把每一章当核对清单，不是强制重写令。

## 目录

- [如何阅读](#如何阅读)
- [1. List](#1-list)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)
