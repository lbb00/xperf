# BEAM 性能指南（v0）— Elixir 与 Erlang

少做平方级 list 增长，少重建 binary，让热循环更安静。

> **范围：BEAM 上的 Elixir 1.14+ 与 Erlang/OTP 25+。** 一个 kit 覆盖两种语言。声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。

## 如何阅读

1. 先**测量**（`:timer.tc`、`fprof`、`eprof`、`Benchee`）。
2. 把每一章当核对清单，不是强制重写令。
3. 扫描扩展名：`.ex`、`.exs`、`.erl`。

## 目录

- [如何阅读](#如何阅读)
- [1. List](#1-list)
- [2. Binary / 字符串与热 I/O](#2-binary--字符串与热-io)
- [Lint 对照](#lint-对照)
