# Objective-C 性能指南（v0）

Foundation 集合、字符串与日志核对清单。与 [swiftperf](../../../swiftperf/) 不同。

> **范围：Objective-C（ARC 或 MRC）。** lint 是对 `.m`/`.h` 的行窗扫描。加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（Instruments Time Profiler / Allocations）。升为更高严重级别前，请在真机或 macOS 上测量。

## 目录

- [1. 集合](#1-集合)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [3. Formatter、JSON 与正则](#3-formatterjson-与正则)
- [Lint 对照](#lint-对照)

