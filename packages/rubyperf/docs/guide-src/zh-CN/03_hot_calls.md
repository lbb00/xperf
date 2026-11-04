## 3. 编译与解析

`Regexp.new` 每次调用都编译。正则字面量会被缓存。对固定 payload 的 `JSON.parse` / `generate` 会重复解析。变化的 payload 不能外提。这些 lint 是 **hint**，并有微基准。`Date.parse` / `Time.parse` / `DateTime.parse` 已移除，原因与固定字符串解析相同：after 侧仅靠不解析才赢。

对同一路径 `File.read` 约 346×（相对读一次）。`File.open` 属同一 lint。每轮都变的路径不能外提。`Process.clock_gettime` 约 2.3×，`send` 约 1.9×；已检查但未给规则。

配套 lint：**rb-regexp-new-hot**、**rb-json-hot**、**rb-file-read-hot**。
