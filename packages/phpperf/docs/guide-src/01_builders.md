## 1. Strings and arrays

`$s .= $piece` in a loop can still be costly at scale; prefer collectors + `implode`. Repeated `$a = array_merge($a, …)` copies; prefer `$a[] = $item`.

Lint: `ph-string-dot-hot` (default off); `ph-array-merge-rebind` (default error).

