## 2. 字符串与热 I/O

循环里的 `stringByAppendingString:` 会分配许多不可变字符串。优先 `NSMutableString`。不要把 `NSLog` 放进紧密循环（门控，或谨慎使用 os_log）。

Lint: `oc-nsstring-append-hot`, `oc-nslog-hot`（默认 off）
