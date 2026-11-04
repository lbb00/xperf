## 1. 容器与字符串

不 `reserve` 就反复 `push_back`，在扩容拷贝占主导时（大 N / 许多 builder）会重新分配。已知最终大小时，优先一次定容。

`std::string` 对**多字节块**或已知最终大小做 `+=` / `append` 时，`reserve` 有益。`-O2` 下单字符 `+=` 往往已摊销（约 1×）——不要把每次 `+=` 都当成速度 bug。

`const std::string` 或 `const std::vector` 形参，以及 range-for 里按值拷贝这些类型，会在每次调用或每个元素上拷贝。跨翻译单元时，64 字节字符串形参相对 const 引用约 15×，vector 里一个 `int` 约 17×。128 字节字符串的 range-for 约 21×，64-int vector 的 range-for 约 21×。4 字符字符串约 1.01×，空 vector 约 1.2×，对 4096 字节字符串按字节求和约 1.3×。lint 不碰非 const 按值形参，因为那也是所有权转移的写法。

遍历打包的 bool 特化（`vector<bool>`）相对 `vector<unsigned char>`，在 2,000,000 元素上约 12×。下标读约 4.2×，带 reserve 的 `push_back` 约 6.9×，未过线。八百万元素在打包容器里占 1,000,000 字节，在字节容器里占 8,000,000 字节。hint 针对遍历。它不是打包其他 bool 字段的理由；当更小体积才是目标时，保留打包布局是合理的。

配套 lint：**cx-const-by-value**、**cx-vector-bool**（默认 **hint**；升级前请测量）。50 万次 `push_back` int 在两次运行上不 `reserve` 约 2.0×；单字符 `string::push_back` 带 `reserve` 更慢（约 0.82× 与 0.79×）。CX001 保持退役：一个匹配器分不清这些情况。2026-10-22 corpus 裁决不覆盖 `cx-const-by-value` 或 `cx-vector-bool`。
