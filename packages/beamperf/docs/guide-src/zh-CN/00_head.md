# BEAM 性能指南（v0）— Elixir 与 Erlang

少做平方级 list 增长，少重建 binary，让热循环更安静。

> **范围：Elixir 1.14+ 与 Erlang/OTP 25+（BEAM）。** 一个 kit 覆盖两种语言。加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。

先画像（`:timer.tc`、`fprof`、`eprof`、`Benchee`）。扫描扩展名：`.ex`、`.exs`、`.erl`。

## 目录

- [1. List](#1-list)
- [2. Binary / 字符串与热 I/O](#2-binary--字符串与热-io)
- [Lint 对照](#lint-对照)

