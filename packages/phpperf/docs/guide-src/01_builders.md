## 1. Strings and arrays

`$s .= $piece` in a loop can still be costly at scale; prefer collectors + `implode`. Repeated `$a = array_merge($a, …)` copies; prefer `$a[] = $item`.

Companion lint: **ph-string-dot-in-loop**, **ph-array-merge-rebind**.

