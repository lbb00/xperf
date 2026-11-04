## 3. 解析与深拷贝

循环里的 `json.loads` / `json.dumps` 与 `deepcopy` 会重复本可在循环外完成的工作（当值不变时）。变化的 payload 不能外提。这些 lint 是 **hint**，并有微基准。`re.compile` 已移除：CPython 会缓存，测得差距低于 3×。`datetime.strptime` / `strftime` 已移除：固定字符串仅在跳过调用时更快，变化的字符串没有可外提的东西。

循环里对同一路径 `open` 会反复打开。某一测量形态（1 字节文件）约 409×。每轮都变的路径不能外提。`time.perf_counter_ns` 约 2.9×，`getattr` 约 1.4×；已检查但未给规则。

配套 lint：**pp-json-hot**、**pp-deepcopy-hot**、**pp-open-hot**。
