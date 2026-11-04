# sp-print-hot — 已测量，保持关闭

**状态:** 已测量。默认保持 **关闭**。

## 主张

`print` 4000 个整数，并且将 stdout 指向 `/dev/null`，大约是用 `String` 构建相同的行的 **10 倍**（1.475 毫秒 对比 0.148 毫秒）。

## 如何测量

- `swiftc -O`，Apple Swift 6.3.2
- 原始文件：[ `sp-print-hot.jsonl`](../sp-print-hot.jsonl)

## 限制

后端不会锁定标准输出。必须打印的日志行不是这个比较。保持默认关闭。
