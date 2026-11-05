# Zig 代码检查工具：范围与比较

有关相关 Zig Linter 的说明以及 `zperf-lint` 的位置。版本会变化；在依赖此表之前请重新检查上游。

## `zperf-lint` 的作用

它会寻找编译器很少标记的性能和内存模式：循环内分配、移动队列、可能的填充、空 I/O 缓冲区以及类似的源代码信号。检查是基于语法的启发式方法。它们不能替代编译、分析、基准测试或常规 lint 检查。

CI 使用社区工具运行它，命令为 `zig run scripts/repo.zig -- lint-all`：正确性工具会阻止执行；样式或版本不匹配的检查仅作建议。总的 CI 配置位于仓库根目录 [`.github/workflows/ci.yml`](../../../../.github/workflows/ci.yml)（任务 `zperf`）。嵌套包工作流已被移除；参见 [`ci/README.md`](../../ci/README.md)。

## 设计边界

- 仅在源模式有明确的性能后果时添加规则。
- 记录误报风险和抑制路径。
- 除非编译器 API 可靠地暴露类型分析，否则不要进行类型分析。
- 将发现视为测量提示——Lint 命中并不等于测量出的加速。

规则和限制：[``zperf-lint``](../../zperf-lint/README.md)。持续集成（CI）：[根目录 `ci.yml`](../../../../.github/workflows/ci.yml) · [`ci/README.md`](../../ci/README.md)。
