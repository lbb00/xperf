# Ruby 性能指南（v0）

少做平方级 builder，让热路径更安静。

> **范围：MRI Ruby 3+。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`benchmark`、stackprof）。JRuby 与 TruffleRuby 不同——请重测。

## 目录

- [1. 字符串、数组与哈希](#1-字符串数组与哈希)
- [2. 热 I/O](#2-热-io)
- [3. 编译与解析](#3-编译与解析)
- [Lint 对照](#lint-对照)

