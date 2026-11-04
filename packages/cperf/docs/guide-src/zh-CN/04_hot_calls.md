## 4. 热路径调用

热循环不应每轮格式化新字符串、打开文件、采样时钟或编译正则。写到已有缓冲、流只开一次、时钟读在稳态外、模式只编译一次。这些 lint 是 **hint**。2026-10-22 语料裁决未覆盖它们。

- **cp-sprintf-hot** —— 循环体内的 `sprintf` 或 `snprintf`。有 JSONL。保持 hint，未做语料 triage。
- **cp-fopen-hot** —— 循环体内的 `fopen`。有 JSONL。保持 hint，未做语料 triage。
- **cp-gettime-hot** —— 循环体内的 `gettimeofday` 或 `clock_gettime`。裸 `time` 不匹配（名字太宽）。有 JSONL。保持 hint，未做语料 triage。
- **cp-regex-hot** —— 循环体内的 `regcomp`。不匹配 `regexec`。微基准相对「编译一次」约 9.7×。保持 **hint**，未做语料 triage。

夹具命中不等于实测加速。见 [evidence-policy.md](evidence-policy.md)。
