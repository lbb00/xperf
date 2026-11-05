# C++ 性能指南（v0）

少做会重新分配的容器，让热路径更安静。

> **范围：C++17。** 加速数字会标明本地 bench、上游来源，或标为暂定。语料库残留计数是 lint 命中次数，不是墙钟耗时节省。
>
> **cppperf 与 cperf：** 本 kit 专攻 C++。同级 **cperf** 覆盖 C11/C17（+ 轻度 C++）。`std::vector` / `std::string` / iostream 类 smell 优先用本 package。

先画像（`perf`、Tracy、`std::chrono`）。libstdc++ 与 libc++ 不同——请重测。

## 目录

- [1. 容器与字符串](#1-容器与字符串)
- [2. 热 I/O](#2-热-io)
- [3. Regex、flush 与时钟](#3-regexflush-与时钟)
- [Lint 对照](#lint-对照)

