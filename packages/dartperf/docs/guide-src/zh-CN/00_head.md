# Dart 性能指南（v0）

少做 list 扩容，少产生字符串 `+` 临时对象，让热循环更安静。

> **范围：Dart 3.x（VM / Flutter）。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`benchmark_harness`、DevTools CPU profiler）。各章是核对清单，不是强制重写令。

## 目录

- [1. List](#1-list)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [Lint 对照](#lint-对照)

