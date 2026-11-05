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

## 1. 容器与字符串

不 `reserve` 就反复 `push_back`，在扩容拷贝占主导时（大 N / 许多 builder）会重新分配。已知最终大小时，优先一次定容。

`std::string` 对多字节块或已知最终大小做 `+=` / `append` 时，`reserve` 有益。`-O2` 下单字符 `+=` 往往已摊销（约 1×）——不要把每次 `+=` 都当成速度 bug。

`const std::string` 或 `const std::vector` 形参，以及 range-for 里按值拷贝这些类型，会在每次调用或每个元素上拷贝。跨翻译单元时，64 字节字符串形参相对 const 引用约 15×，vector 里一个 `int` 约 17×。128 字节字符串的 range-for 约 21×，64-int vector 的 range-for 约 21×。4 字符字符串约 1.01×，空 vector 约 1.2×，对 4096 字节字符串按字节求和约 1.3×。lint 不碰非 const 按值形参，因为那也是所有权转移的写法。

遍历打包的 bool 特化（`vector<bool>`）相对 `vector<unsigned char>`，在 2,000,000 元素上约 12×。下标读约 4.2×，带 reserve 的 `push_back` 约 6.9×，未过线。八百万元素在打包容器里占 1,000,000 字节，在字节容器里占 8,000,000 字节。hint 针对遍历。它不是打包其他 bool 字段的理由；当更小体积才是目标时，保留打包布局是合理的。

Lint: `cx-const-by-value`, `cx-vector-bool`（默认 hint；升级前请测量）. 50 万次 int `push_back` 在两次运行上不 `reserve` 约 2.0×；单字符 `string::push_back` 带 `reserve` 更慢（约 0.82× 与 0.79×）。CX001 保持退役：一个匹配器分不清这些情况。2026-10-22 语料裁决不覆盖 `cx-const-by-value` 或 `cx-vector-bool`。
## 2. 热 I/O

紧密循环里的 `std::cout << ...` 会刷新并格式化。画像显示有压力时，优先缓冲写入，或把 `{fmt}` / `printf` 放到循环外。

没有 lint 覆盖该 smell（CX003 已退役）。
## 3. Regex、flush 与时钟

循环里构造 `std::regex` 每轮都编译。短 haystack 上相对构造一次约 7.7×。外部流上的 `std::endl` 每次插入都 flush（相对换行 + 一次 flush 约 23×）。字符串流上的同一操纵符约 0.87×，因此那种形态不是 finding。每轮采 `steady_clock::now` 相对采一次约 147×；需要新鲜时间戳的循环没有可外提的东西。每轮建 string stream 在 `-O2` 下约 1.2×，该规则已移除。这些 lint 保持 hint。它们不属于 2026-10-22 corpus 裁决。

对同一路径 `ifstream` 约 2025×（相对打开一次）。每轮都变的路径不能外提。这不会复活已移除的 CX003 id。

Lint: `cx-regex-ctor-hot`, `cx-endl-hot`, `cx-clock-hot`, `cx-ifstream-hot`（默认 hint）
## Lint 对照

| ID | Smell | 默认 |
|----|-------|------|
| CX001 | 已移除（抖动） | — |
| cx-regex-ctor-hot | 循环内构造 `std::regex` | hint（有 JSONL；未 corpus 分级） |
| cx-endl-hot | 循环内 `endl` flush | hint（有 JSONL；未 corpus 分级） |
| cx-clock-hot | 循环内采时钟 | hint（有 JSONL；相对一次采样约 147×；未 corpus 分级） |
| cx-ifstream-hot | 循环内打开文件流 | hint（有 JSONL；单字节文件约 2025×；未 corpus 分级） |
| cx-const-by-value | 按值拷贝 `const` string 或 vector | hint（有 JSONL；拷贝会分配时约 15–21×；未 corpus 分级） |
| cx-vector-bool | 打包 bool 元素容器 | hint（有 JSONL；遍历相对字节 vector 约 12×；未 corpus 分级） |
| CX003 | 已移除（抖动） | — |
| CX004 | 已移除（抖动） | — |

仅在有 `evidence/cx-*.jsonl` 时升级——见 [evidence-policy.md](evidence-policy.md)。退役的 CX004 表明 `-O2` 可能抹掉效果；若声称速度，请在 `-O0` / sanitizer 下测量。

## 参考资料

- [XPerf playbook](../../../../docs/zh-CN/playbook.md)
