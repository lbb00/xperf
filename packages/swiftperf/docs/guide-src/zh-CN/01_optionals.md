## 1. Optional 与热路径

紧密循环里的强制解包（`!`）在 nil 时会崩，并跳过更安全的控制流。优先每轮一次 `guard let` / `if let`，或外提。

在非 nil 数组上，强制解包与 `if let` 耗时相同，因此没有对应 lint。
