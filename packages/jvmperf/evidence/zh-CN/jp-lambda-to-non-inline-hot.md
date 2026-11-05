# jp-lambda到非内联热

## 主张

传递给**非内联**高阶函数的 Lambda 会进行封装/分配；`inline` 可以将分配保持在接近零的水平。

## 如何测量

- 来源：`K14_LambdaCopyAlloc.jsonl`
- JDK **27 (27+35)**，Kotlin **2.4.21**，JVM 参数 `-XX:+UseCompactObjectHeaders`。Linux x64，负载 0.21。
- **之前：** `repeatSumBoxed_n1e4`
- **之后：** `repeatSumInline_n1e4`

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| When | 2026-10-23 |
| before | **15439.7** ns_per_op, **3897.9** B/op |
| after | **32990.8** ns_per_op, **16.0** B/op |
| **前/后比率** | **约0.47×** 时间，**约244×** B/操作 |

## Lint 映射 / 策略

分配仍然大约是 244×（之前约为 283×）。这次运行时间方向相反：非内联调用更快，大约为 0.47×。对于分配该规则保持不变。`Rule.java` 中的默认严重性是 **关闭**（使用 `--enable` 运行它）。

## 限制

在这台机器上进行微基准测试；请参见 `scripts/run-static-vs-hotspot.sh`。不要随意编造比率。语料残差 ≠ 加速比。
