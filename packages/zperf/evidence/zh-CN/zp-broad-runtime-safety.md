# zp-broad-runtime-safety — 待定措施

## 状态

**待处理措施** — 尚无 `evidence/zp-broad-runtime-safety.jsonl`。

## 原因

Broad `@setRuntimeSafety(false)` 只有在 **ReleaseSafe** 下（安全检查仍在运行）才有一个有意义的实时时钟故事。本次传递的测试平台是 `-Ofast` / ReleaseFast 形状的，并未提交 ReleaseSafe 配对。

## 为什么没有 JSONL

错误的优化模式会低估或虚构一个胜利。

## 解阻条件

在 `evidence_fill.zig`（或同级）中专用 ReleaseSafe 前/后，median≥9，然后添加 `.jsonl` 并更新此 md。在此之前保持警告/审查。
