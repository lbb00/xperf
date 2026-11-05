# 变更日志

此文件记录了该项目的所有重大变更。

该格式基于 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，
且本项目遵循 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)。
版本适用于整个仓库，并作为 git 标签（见 [docs/release.md](../docs/zh-CN/release.md)）。
套件不会单独发布，也没有自己的版本。

## [未发布]
- **文档 zh-CN:** 面向共享文档的站点 Markdown 中文覆盖、工具包指南（`guide-src/zh-CN` + build-guides 核心匹配）、软件包介绍、语料/证据政策/规则 ID、活动证据笔记，以及通过 `zh-CN/` 父目录发布为 `*.zh.md` 的根页面。放在 `evidence/_removed/` 下的作废证据故意保持仅英文。

- **文档SEO / GEO （en + zh）:** 描述，开放图（“og：locale” + “alternateLocale”），Twitter Card，规范和 hreflang;静态导出强制阻挡元数据进入 HTML（'htmlLimitedBots'）;'sitemap.xml' 将 en/zh 与语言替代配对;'robots.txt' 允许通用的 AI 爬虫;'llms.txt' + 'llms.zh.txt';区域感知 JSON-LD（“WebSite” / “WebPage” / “SoftwareApplication”）;构建后集 '<html lang=“zh-CN”>' 在 '/zh/' 下表示爬虫;1200×630 'og.png'。README 以仅英语的值前置钩子开头。

- **文档网站：** 页面链接不再保留末尾的 `.md`（在 GitHub Pages 上会返回 404）。Assemble 会将其重写为相对于页面目录的带斜杠的目录 URL，如果仍有 `.md` href，会导致构建失败，还会以根绝对路径输出静态文件，从而使 `/zh/` 语言环境正常工作，并将 `LICENSE` / `NOTICE` 作为目录发布，以便 `trailingSlash` 可以打开它们。

- **所有套件：** 默认匹配为 **`--scope all`**，适用于套件 CLI 支持的情况（要在仅循环匹配中使用之前版本，请选择 **`--scope loop`**）。查找消息不再意味着非循环站点不在范围内。包含 `in-loop` 的规则标识符已 **重命名** 为 `*-hot`（包括剩余的 `rs-map-new-in-loop` → `rs-map-new-hot`；参见每个套件的重命名表）；旧标识符在每个套件的 `evidence/_removed/*.REMOVED.md` 下被标记为废弃，且绝不能重新使用。请参阅每个套件的 `docs/rule-ids.md` 重命名表。jsperf 还保留了早期提交中采用者的 FP 删除及新提示。没有严重性升级。

- jsperf-lint：默认 **`--scope all`** 会在所有地方报告以前的循环内代码异味（极致性能默认）；可选择 **`--scope loop`** 来使用旧的仅循环内匹配。发现消息和文档不再意味着非循环位置不在范围内。仍然包括循环头 / 嵌套函数的虚假正例切割；路径会跳过 `e2e/`、`playwright-report/` 和 `*.test.*` / `*.spec.*`；新增提示 `jp-query-all-star`、`jp-execjs-in-timer` 和 `jp-clone-per-event`（保持提示）；扫描器读取 `executeJavaScript` / `evaluate` 模板中的 JS。没有严重性升级；`jp-string-plus-in-loop` 保持废弃状态。

- 文档站点使用 Fumadocs 布局：侧边栏、命令搜索和 Geist。页面由 Node 组装。

- 用于指南和工具包文档的 GitHub Pages 网站，由树中已有的 Markdown 构建。

- 删除了已签入的 C# 基准可执行文件及其 .NET 构建输出。

- 将 `rs-map-new-in-loop` 恢复为提示。两次安静的 rustc 1.99 运行，每次执行 20000 次单键插入，相对于清空一个映射的速度大约为 1.53× 和 1.51×。同样的两次运行中，大型 `Vec` 填充约为 1.00×，大型 `String` 填充约为 1.03×，所以那些删除保持不变。

- 当前工具链上的安静重跑。Rust 1.99：`Instant::now` 大约快 20 倍（旧的 439 倍，后期约 0.008 毫秒），`File::open` 大约快 416 倍，`Regex::new` 在 `regex` 1.13.1 上大约快 963 倍。全部保持提示。Nim 2.2.12 `&=` 与 `join` 大约是 0.79 倍；`nm-string-amp-in-loop` 被移除，slug 不再重用。

- 编译、解析、打开和时钟规则的提示文本现在说明了基准前提：只有当模式、文本、路径或时间戳保持不变时才提升。在调用中，如果参数是循环绑定，则不报告。在 C#、Swift 和 Rust 中，循环内部的 `Date` / `Stopwatch` / `Instant::now`（如果循环包含 `await`）不会被报告。ArkTS 不再报告 `for` / `forEach` / `map` 的头部的 `JSON.parse`。Elixir 的 `Enum.map`/`filter` 表示成本会随长度增长。

- JavaScript 中的 `jp-string-plus-in-loop` 已被移除。`push` 然后 `join` 并不是关于在短字面量上 `2×` 与 `+=` 的比较，也不是关于 `String.fromCharCode` 或 64 字符的字面量（在 22000 个字符时 `join` 更慢）。`jp-map-filter-chain` 现在支持 JSONL 并保持提示：35000 行约 4.6× 和 9.8×，一个 3 行的 filter+map 为 1.28×。提示行说明了基准前提。在 `for` 可迭代对象中使用 `readFileSync`、在带 `await` 的循环中使用 `Date.now`、以及 `new RegExp` / `JSON.parse` / DOM 选择器 / `Intl.DateTimeFormat` 且其参数为循环绑定的情况未被报告。

- 在这台机器上测量了先前未进行基准测试的 C 和 Swift 形状。在条件中的 `strlen` 大约是字符串可能变化时提升后的长度的 125 倍，而当 `-O2` 已经提升它时大约是 0.93 倍（`cp-strlen-in-cond`，仍然提示）。固定块的 `strcat` 大约是末端指针的 221 倍（`cp-strcat-hot`，保持关闭）。Swift 的 `reserveCapacity` 在许多小数组上大约是 5 倍，在一个大数组填充上大约是 1.6 倍（`sp-array-no-reserve`，仍然提示）。打印到 `/dev/null` 大约是一个 `String` 的 10 倍（`sp-print-hot`，保持关闭）。移除了 `sp-string-plus-in-loop`（reserve 更慢）、`sp-map-joined-chain`（大约 1.2 倍）和 `sp-force-unwrap-in-loop`（与 `if let` 时间相同）。- 移除了接近 1× 的匹配器：`at-object-delete`（在 Node 代理上约 1.01×）、`cx-string-append-unreserved`（时间约 1.09×，容量低于 1.4×）、`rs-string-plus-in-loop`（在大量填充上约 1.00×）、`rs-vec-no-capacity`（在大量填充上时间约 1.00×，字节约 1.05×）以及 `zp-extern-struct-padding`（遍历约 1.21×，24 字节对比 16 字节）。这些 slug 已被标记为已删除且不再重复使用。`format!` 重新绑定、值类分配和 `alloca` 栈增长依然存在。
- Zig 提示：对未改变格式字符串和参数的 `allocPrint` / `Allocator.print`，在通用分配器上约 50×，在 arena 上约 12×，对常量字符串约 14×（`zp-alloc-print-hot`）。`bufPrint`、`Writer.print`、字节拷贝以及 256 字节结构拷贝维持在约 7× 以下，未新增。空缓冲区 `writeByte` 约 130×，但在 4KiB 缓冲区上相同调用约 1.2×，因此未新增。默认提示保持不变。- C++提示:`Const std: string ' /`Const std:vector ' 按价值计算大约为15-21xx,相对于副本分配时的cost参考(`cx-const-by-value ' )。 4个字符串大约为1××,仍然提示着. 步行`车手<bool>`>大约是`车手<未署名的车'(`cx-vector-bool ' );包装的集装箱较小。 牵引 'std:: 函数 ' 速度较慢(约0.6×)。 复制 " share ptr " 停留在 7x以下。 `图::操作器[...]在缺失的密钥上大约为30××,但现有密钥上相同的拼写速度比`查找 ' 慢,因此没有添加。 默认保留提示 。
- C提示:`aloca'在一个循环中覆盖堆栈(20,000×64字节对1个64字节缓冲),而触摸时间则停留在1×左右(`cp-aloca-hot')。 横跨两个翻译单位的512字节结构对一个指针( " cp-struct-by-value " )的数值是12.3×。 在一个翻译单元中,相同的形状约为1×. `fgetc ' /`fputc ' /`putc ' 读作(约24-120x),速度更快,但没有添加:一行匹配者无法从批量读作中看出字节解析器。 默认保留提示 。- 跨语言检查文件打开和时钟样本。新的提示，每个都有 JSONL，其中相同的形状代价很高，而标准库可以重用句柄或样本：Python `open` (~409×)、JavaScript `readFileSync` (~480×)、`Date.now` (~26×)、和 `performance.now` (~19×)、Go `os.Open` (~2300×) 和 `time.Now` (~104×)、Ruby `File.read` (~346×)、C# `File.ReadAllText` (~1560×) 和 `Stopwatch.GetTimestamp` (~15×)、Rust `File::open` (~2750×) 和 `Instant::now` (~439×)、Swift `contentsOfFile` (~414×)、Objective-C `stringWithContentsOfFile` (~450×)。C# `new Regex(` 现在匹配 `cs-regex-hot` (~7×，双方仍然匹配)。Python `perf_counter_ns` (~2.9×)、Ruby `Process.clock_gettime` (~2.3×)、`getattr` (~1.4×)、`send` (~1.9×) 和 JavaScript `Reflect.get` (~8×) 已检查但未添加。默认保持提示。- 对于一个一字节文件，C++ 的 `ifstream` 每次打开约为一次性打开的 2025 倍（`cx-ifstream-hot`，提示）。Zig 0.17 的 `openFileAbsolute` 大约是 2134 倍，而 `Clock.awake.now` 大约是 42 倍（`zp-open-file-hot`、`zp-clock-hot`，提示）。C# 中每次迭代的 `GetField` 加 `GetValue` 大约是直接访问字段的 62 倍（`cs-field-by-name-hot`，提示）。Zig 的 `json.parseFromSlice` 解析一个小对象，大约是一次性解析的 2683 倍（`zp-json-hot`，提示）。Objective-C 的 `valueForKey:` 大约是 124 倍，Swift 的 `value(forKey:)` 大约是 35 倍，相对于直接访问字段（`oc-value-for-key-hot`、`sp-value-for-key-hot`，提示）。Swift `Date()` 的公平重跑约为 244 倍，Objective-C `[NSDate date]` 约为 769 倍，并且循环后保持存活。两者都是带有 JSONL 的提示。第一次被丢弃的运行已删除了那个循环。

- 公平重跑：移除了 `cx-sstream-in-loop`、`pp-regex-compile-in-loop`、`rs-map-new-in-loop`、`pp-datetime-format-in-loop`、`gp-time-parse-in-loop` 和 `rb-date-parse-in-loop`（接近 1×，或者唯一的收益是跳过调用）。`cx-endl-hot` 在外部流大约 23×，而在字符串流大约 0.9×。`gp-reflect-hot` 现在匹配名称查找和 `reflect.New`；`TypeOf` 大约 1.3×，并未匹配。`cp-regex-hot`、`cx-clock-hot`、`cs-json-hot`、`rs-regex-new-hot`、`jp-dom-query-hot` 和 `jp-intl-datetimeformat-hot` 拥有 JSONL 并保持提示。每次迭代都更改的 JSON 或日期值无法提升。Java `SimpleDateFormat` 未被添加：在此环境中没有 JDK。

- 在Python、JavaScript、Go、C++、C#、Ruby和Rust中提示重复编译、解析、查询、格式和新地图工作的规则。 只有佩尔德的固定装置。 没有JSONL,所以他们没有一个是`错误的'。 2026-10-22命案判决不涵盖这些流弹.
- C提示 " sprintf " / " fopen " / " clock " 环读,四面或四面以上布林旗帜( " cp-wide-bool-flags " )。 只有佩尔德的固定装置。 没有JSONL。 没有被吓到
- 快速提示在循环中构建日期标、JSON解码器或`NSRegularExpression'。 斯威夫特扫描仪和文本背面都携带着它们. 只有佩尔德的固定装置。 没有JSONL。 没有被吓到
- 目标-C:指定一个日期,称为 " NSJSONSerialization " ,或在循环中建立 " NSRegularExpression " 。 只有佩尔德的固定装置。 没有JSONL。 没有被吓到
用于一个形状(编译/parse/format/复制)的新提示规则的Microbench JSONL。 默认保留提示 。 `cx-endl-hot ' 和`gp-reflect-hot ' 大约为1×。 `jp-dom-query-hot ' 和`rs-regex-new-hot ' 没有定时。

## [0.1.0] — 2026-10-22

伞首个公开形态快照（亚洲/上海）。

- 在 `packages/*` 下有 19 套语言包，语料库准备就绪，见 AGENT.md G3。
- 规则 ID 仅为语义标识 (`{family}-{smell}`)；数字编码已移除（无别名）。
- 已删除无用规则（墓碑），未保留为僵尸 `off`。
- 根 README 已精简；套件状态 → `docs/kits.md`；运行命令 → `docs/quickstart.md`。
- 标记时约有 124 个活跃标识；参见各套件的 `docs/rule-ids.md`。
