# zp-可选标量字段 — 待定措施

## 状态

**待处理措施** — 尚无 `evidence/zp-optional-scalar-field.jsonl`。

## 原因

可选的标量填充/布局空洞是一个**密度**声明。没有带宽可以利用此通道。

## 为什么没有 JSONL

与 zp-packable-bools/zp-usize-index-field 属于同一类——需要防止内存流量问题，而不是一个小循环。

## 解阻条件

有可测缓存效果的紧凑与填充结构数组扫描；然后是 JSONL。在此之前，该规则保持 **关闭**。
