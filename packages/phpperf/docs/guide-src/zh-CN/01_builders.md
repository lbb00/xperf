## 1. 字符串与数组

循环里的 `$s .= $piece` 在规模变大时仍可能昂贵；优先收集器 + `implode`。反复 `$a = array_merge($a, …)` 会拷贝；优先 `$a[] = $item`。

配套 lint：**ph-string-dot-hot**、**ph-array-merge-rebind**。
