## 5. 标志布局

一条记录上的若干开关属性（例如某车有哪些动力源），在大量副本共享紧张 RAM 预算时，不必每个都占满一个整数。混合（电动与汽油并存）是位组合，不是互斥枚举值。

要紧的是 `sizeof`，它包含对齐填充。四个 `int` 标志占四个 `int`：`int` 16 位时 8 字节，32 位时 16。位域宽度不是那个尺寸。`unsigned` 位域常存进一个 `unsigned int`，所以四个 1 位字段仍可能占 4 字节。`unsigned char` 位域可共享一字节。单个 `unsigned` 掩码是另一种紧凑形式。在你交付的 ABI 上检查 `sizeof`。

关掉对齐或 packing pragma 是目标选择。有的 CPU 对未对齐加载会故障或变慢。本 hint 不要求那样做。

**cp-wide-bool-flags** 在一个 struct 有四个及以上全宽 `bool` / `_Bool` 成员，或四个及以上名为 `is_` / `has_` / `can_` 的 `int` / `unsigned` 成员、且没有位域时开火。这是 **hint**。有 JSONL。保持 hint；2026-10-22 语料裁决未覆盖。桌面上少量记录可以忽略。JVM 上类似的对象头规则在测量显示无占用收益后已移除；本 C hint 不是那次测量。

夹具命中不等于实测节省。见 [evidence-policy.md](evidence-policy.md)。
