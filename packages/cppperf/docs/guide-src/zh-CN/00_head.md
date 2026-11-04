# C++ 性能指南（v0）

少做会重新分配的容器，让热路径更安静。

> **范围：C++17。** 声称加速的断言会点名本地示例，或标明暂定。**Corpus lint 计数是启发式 dogfood**，不是基准。
>
> **cppperf 与 cperf：** 本 kit 专攻 C++。同级 **cperf** 覆盖 C11/C17（+ 轻度 C++）。`std::vector` / `std::string` / iostream 类 smell 优先用本 package。

## 如何阅读

1. 先**测量**（`perf`、Tracy、`std::chrono`）。
2. 把每一章当核对清单。
3. libstdc++ 与 libc++ 不同——请重测。

## 目录

- [如何阅读](#如何阅读)
- [1. 容器与字符串](#1-容器与字符串)
- [2. 热 I/O](#2-热-io)
- [Lint 对照](#lint-对照)
