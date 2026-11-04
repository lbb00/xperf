# Objective-C 性能指南（v0）

Foundation 集合 / 字符串 / 日志核对清单。与 **swiftperf** 不同。

> **范围：Objective-C（ARC 或 MRC）。** Lint 是对 `.m`/`.h` 的行窗口扫描。升级前请在设备/macOS 上测量。

## 如何阅读

1. 先**测量**（Instruments Time Profiler / Allocations）。
2. 把每一章当核对清单，不是强制重写令。

## 目录

- [0. 范围与方法](#0-范围与方法)
- [1. 集合](#1-集合)
- [2. 字符串与热 I/O](#2-字符串与热-io)
- [3. Formatter、JSON 与正则](#3-formatterjson-与正则)
- [Lint 对照](#lint-对照)
