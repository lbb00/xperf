## 1. List 与字符串

循环里的 `List.Add` 若不设 `Capacity` 会反复扩容。优先一次定容。紧密循环里的字符串 `+=` 会分配；优先 `StringBuilder`。

每轮调用静态 `Regex.IsMatch` / `Regex.Match` 并传入模式字符串，都会在静态正则缓存里查找；优先复用一个 `Regex` 实例（热模式可用 `RegexOptions.Compiled`）。

配套 lint：**cs-list-add-no-capacity**、**cs-string-plus-hot**、**cs-regex-hot**。
