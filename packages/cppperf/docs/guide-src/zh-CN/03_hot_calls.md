## 3. Regex、flush 与时钟

循环里构造 `std::regex` 每轮都编译。短 haystack 上相对构造一次约 7.7×。外部流上的 `std::endl` 每次插入都 flush（相对换行 + 一次 flush 约 23×）。字符串流上的同一操纵符约 0.87×，因此那种形态不是 finding。每轮采 `steady_clock::now` 相对采一次约 147×；需要新鲜时间戳的循环没有可外提的东西。每轮建 string stream 在 `-O2` 下约 1.2×，该规则已移除。这些 lint 保持 hint。它们不属于 2026-10-22 corpus 裁决。

对同一路径 `ifstream` 约 2025×（相对打开一次）。每轮都变的路径不能外提。这不会复活已移除的 CX003 id。

Lint: `cx-regex-ctor-hot`, `cx-endl-hot`, `cx-clock-hot`, `cx-ifstream-hot`（默认 hint）
