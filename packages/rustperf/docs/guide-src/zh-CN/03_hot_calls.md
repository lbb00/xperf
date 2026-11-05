## 3. Regex

循环里的 `Regex::new` 会反复编译模式。在 `regex` 1.13.1 与 rustc 1.99 上，每轮构造再匹配短 haystack，相对构造一次约 963×（两侧仍匹配）。该 lint 为 hint。`HashMap::new` 加一次 insert，重复 20000 次，相对清空同一 map 约 1.5×（两次安静的 rustc 1.99 运行；`rs-map-new-hot`，hint）。

对同一路径 `File::open` 在 rustc 1.99 上约 416×（相对打开一次）。`Instant::now` 约 20×（相对采一次样）。变化的路径不能外提；需要新鲜时间戳的循环也没有可外提的东西。

Lint: `rs-regex-new-hot`, `rs-file-open-hot`, `rs-clock-hot`（默认 hint）
