## 6. 构造函数、JSON、DOM 查询与日期格式

下列每条 hint 对应一种实测 shape。hint 行陈述该前提。只是看起来像的调用不给那套重写。默认 **`--scope all`** 到处报告这些味道——极端栈把点滴成本也算进范围，即便不在循环里。可选用 **`--scope loop`** 恢复从前的仅循环内匹配。消息不会告诉读者或模型可以忽略非循环位点。

`new RegExp(pattern)` 在模式不变时每次调用都编译。正则字面量会被缓存。若模式是循环变量或 `parts[i]`，检查器不会说编译一次。基准编译一个固定模式，Node 26 上约 4.4×。

对不变文本的 `JSON.parse`，相对解析一次，Node 26 上约 140×。对不变值的 `JSON.stringify` 是同一 shape。JSONL 行或 `rows[i]` 每轮文本不同。检查器跳过参数就是循环绑定的情况。它不会让你把那些行折叠成一次 parse。

对不变选择器的 `querySelector` / `getElementById`，在 Node 26、很小的 linkedom 文档上约 16×。由循环下标拼出的选择器不是那个基准。用不变 locale 与选项的 `new Intl.DateTimeFormat`，Node 26 上约 36×；两边仍会 format。`new Date` 不是本规则。

对不变路径的 `fs.readFileSync`，相对读一次，Node 26 上约 114×。在 `--scope loop` 下，只匹配 `{` 后的循环体（只跑一次读的 `for` 可迭代随后被跳过）。默认 `--scope all` 下，路径稳定时无论出现在哪都会报。每轮变化的路径（循环绑定）不报。

`Date.now` 约 26×，`performance.now` 约 19×，相对只采样一次，在不 wait 的紧循环里。含 `await` 的循环，或 `for await` 循环，时钟规则不报。不需要每次新鲜时间时采样一次。必须每轮读时钟的限流器没有可搬的东西。

**jp-regex-ctor-hot** 与 **jp-json-hot** 在 app 与 engine preset 上保持 hint。两者有 JSONL，2026-10-22 裁决未覆盖。**jp-dom-query-hot**（Node 26、很小 linkedom 约 16×）与 **jp-intl-datetimeformat-hot**（Node 26 约 36×，两边仍 format）有 JSONL 且保持 hint。它们在该裁决之外。`--preset all` 对仍存在的每条规则是 error。

`Reflect.get` 约 8×，未给规则。

Lint: `jp-regex-ctor-hot`, `jp-json-hot`, `jp-dom-query-hot`, `jp-intl-datetimeformat-hot`, `jp-readfile-sync-hot`, `jp-clock-hot`（默认 hint）
