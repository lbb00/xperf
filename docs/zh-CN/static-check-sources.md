# 静态检查来源汇总

面向 linter 能看见的性能与内存形态的公开来源。这里的一行不是本树的测量。下列数字是来源自己的数字。新 slug 仍需要本地 before/after，且默认保持 hint。

处置：

- **already-ruled** —— 该 kit 已有 slug 覆盖该形态。
- **measure-first** —— 来源描述了扫描器能看见的形态，而本树尚无对应 slug。
- **rejected** —— 来源自身结果很小、反向，或不是稳定规则。
- **no-compiler** —— 本机跑不了该语言，故形态未测。

## cperf

- 循环内的 `alloca` 会把每块保留到函数返回。[Stack Overflow](https://stackoverflow.com/questions/5407546/memory-allocated-with-alloca-gets-freed-at-end-of-function-or-at-end-of-scope)。**already-ruled**（`cp-alloca-hot`）。本地栈覆盖 1280000 字节对比 64。触摸时间约 1×。
- 逐字节 `fgetc` / `fputc`。问题报告相对 4096 字节 `fread` 约 10×。[Stack Overflow](https://stackoverflow.com/questions/13225014/why-fgetc-too-slow)。**rejected**。本地块读更快，且行匹配器分不清字节解析器与批量读。
- 循环 `malloc`、按一增长的 `realloc`、`strcat`、`sprintf`、`fopen`、`gettimeofday`，以及一长串布尔字段，均 **already-ruled**。

## cppperf

- 循环内构造 `std::function` 在捕获装不进小缓冲时会堆分配一次。[The cost of captures](https://zvxryb.github.io/blog/2018/02/18/the-cost-of-captures/)。**rejected**。本地 sink 重跑让提升后的 `std::function` 更慢（约 0.6×）。
- 按值复制 `shared_ptr` 会 bump 原子计数。[GotW #91](https://herbsutter.com/2013/06/05/gotw-91-solution-smart-pointer-parameters/) 与 [按值传递写稿](https://ddanilov.me/shared-ptr-is-evil/)。**rejected**。本地复制约 4.8×，且变化值的 `make_shared` 无法提升。
- `const std::string` / `const std::vector` 按值，在拷贝会分配时相对 const 引用约 15–21×。**already-ruled**（`cx-const-by-value`）。4 字符字符串约 1×，hint 仍开火。
- 遍历 `vector<bool>` 相对字节向量约 12×，且打包容器用更少字节。**already-ruled**（`cx-vector-bool`）。
- 无 reserve 的 `std::string` 追加、`endl`、正则构造、时钟与 `ifstream` 均 **already-ruled**。字符串流在公平重跑后已移除。

## csharpperf

- 循环内用 `+` 建字符串会分配。[Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/strings/common-tasks/concatenate)。**already-ruled**（`cs-string-plus-hot`）。
- C# 10 插值不再落到旧的装箱 `string.Format` 路径。[Microsoft .NET blog](https://devblogs.microsoft.com/dotnet/string-interpolation-in-c-10-and-net-6/)。在本地 .NET 8 跑出相反结论前，作为「插值很慢」规则 **rejected**。
- `File` 读、`Stopwatch.GetTimestamp`、`GetField`、JSON、正则与 `ToList` 均 **already-ruled**。

## goperf

- 循环里 `s += part` 会复制整串。预增长的 `strings.Builder` 只分配一次。[String concatenation vs strings.Builder](https://vvivid.dev/posts/go_string_concat_vs_string_builder/)。**already-ruled**（`gp-string-plus-hot`）。
- 短片段列表上 `bytes.Buffer` vs `strings.Builder` 在该机约 1.5×。[brandur.org](https://brandur.org/fragments/bytes-buffer-vs-strings-builder)。**rejected**。
- 循环里的 `fmt`、单载荷 `json`、`os.Open`、`time.Now`、`regexp` 编译与 `FieldByName` 均 **already-ruled**。

## jsperf

- 对象上的 `delete` 会把它迁到 dictionary 属性。[V8 fast properties](https://v8.dev/blog/fast-properties)。**already-ruled**（`jp-delete-shape`）。
- 删除数组元素或读洞会翻转元素存储。[web.dev V8 tips](https://web.dev/articles/speed-v8)。**already-ruled**（`jp-delete-array-hole`）。
- 预分配巨大数组（该页引用超过 64K）在该页被点名。仅对扫描器能看见、又不误伤普通数组的字面量巨大 `new Array(n)` 做 **measure-first**。
- 正则构造、单载荷 `JSON.parse`、`readFileSync`，以及 `Date.now` / `performance.now` 均 **already-ruled**。

## pyperf

- 对某些 shape，CPython 上 `str` 的 `+=` 可以快于 `''.join`。[String concatenation in Python](https://blog.ganssle.io/articles/2019/11/string-concat.html)。`str` 已 **already-ruled**（`pp-str-plus-hot`）。不要仅凭旧的平方故事再加第二条 join 规则。
- `[None] * n` 对比 `append` 在帖子计时约 1.3×。[Stack Overflow](https://stackoverflow.com/questions/63599687/is-it-better-to-pre-allocate-array-in-python-or-use-arr-append)。**rejected**。
- 用 `+=` 建 `bytes` 对比 `b''.join` 被报差距很大。[Fast bytes concatenation](https://www.guyrutenberg.com/2020/04/04/fast-bytes-concatenation-in-python/)。**measure-first**。
- 单载荷的 `open` 与 `json.loads` 均 **already-ruled**。本地测过 `perf_counter_ns` 与 `getattr` 且未加入。

## rubyperf

- 反复 `+` 会分配。缓冲要用 `<<`。[fast-ruby concatenation](https://github.com/fastruby/fast-ruby/blob/main/code/string/concatenation.rb)。**already-ruled**（`rb-string-plus-hot`）。
- `# frozen_string_literal: true` 在该文极小字面量循环上约 1.2–1.3×。[FastRuby.io](https://www.fastruby.io/blog/ruby-3-4-new-defaults.html)。在真实文件本地跑出更大收益前 **rejected**。
- 单载荷的 `File.read`、`Regexp.new` 与 `JSON.parse` 均 **already-ruled**。本地测过 `Process.clock_gettime` 与 `send` 且未加入。

## rustperf

- `collect` 会分配。返回迭代器，或 `extend` 已有 `Vec`。[The Rust Performance Book](https://nnethercote.github.io/perf-book/iterators.html)。部分 **already-ruled**（`rs-collect-vec-hot`）。
- 切片上的 `iter().cloned().collect()` 应是 `to_vec()`。[Clippy `iter_cloned_collect`](https://github.com/rust-lang/rust-clippy/blob/master/clippy_lints/src/methods/iter_cloned_collect.rs)。**measure-first**。公开声明是「更快」，不是比值。
- 循环内对堆值 `.clone()` 会深拷贝。[Clones and allocations](https://rs4ts.dev/21-performance/03-optimization/)。**measure-first**。Clippy 的 `redundant_clone` 历史上会跳过循环体（[rust-clippy#17495](https://github.com/rust-lang/rust-clippy/pull/17495)）。
- `File::open`、`Instant::now` 与 `Regex::new` 均 **already-ruled**。标准库没有 JSON 解析器。

## swiftperf

- 空数组上一次 `reserveCapacity` 避免几何增长。每轮以 `count + k` 调用会反复拷贝。[Hacking with Swift](https://www.hackingwithswift.com/articles/128/array-performance-append-vs-reservecapacity)。缺 reserve **already-ruled**（`sp-array-no-reserve`）。循环内 reserve 是 **measure-first**。
- `DateFormatter`、`JSONDecoder`、`NSRegularExpression`、`contentsOfFile`、`Date()` 与 `value(forKey:)` 均 **already-ruled**。

## objcperf

- 一长串便利构造（`[NSMutableString string]`）会堆起 autorelease 对象。Apple 文档建议循环内 `@autoreleasepool` 削峰值。[Autorelease pool blocks](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html) 与 [Stack Overflow](https://stackoverflow.com/questions/16162878/autorelease-pool-blocks)。对缺失 pool 做 **measure-first**。每轮创建 pool 很便宜（[mikeash.com](https://www.mikeash.com/pyblog/autorelease-is-fast.html)），故规则不得误伤已有 pool。
- `stringByAppendingString`、`NSLog`、日期格式化器、JSON、正则、文件读、`NSDate` 与 `valueForKey:` 均 **already-ruled**。

## zperf

- 每轮新建 `ArrayList` 会分配。复用一个 list 并调用 `clearRetainingCapacity` 在该帖与栈缓冲相当。[ziglang/zig#16982](https://github.com/ziglang/zig/issues/16982)。循环内堆分配 **already-ruled**（`zp-alloc-hot`、`zp-create-destroy-hot`）。不要为同一形态再加 slug。
- `std.fmt.allocPrint` 分配新切片。[lib/std/fmt.zig](https://github.com/ziglang/zig/blob/master/lib/std/fmt.zig)。格式串与参数不变时 **already-ruled**（`zp-alloc-print-hot`）。本地 ReleaseFast 中位数：通用分配器约 50×，arena 约 12×，常量串约 14×。`bufPrint` 与字节拷贝约 ≤7×，未加入。
- 文件打开、`Io.Clock` 与单载荷 `json.parseFromSlice` 均 **already-ruled**。0.17 标准库没有正则编译器。

## jvmperf

- 循环内用 `StringBuilder` 代替 `+` 是经典形态。[byroot 的比较](https://byroot.github.io/ruby/performance/2025/10/28/string-literals.html) 重述了它。**already-ruled**（`jp-string-concat-hot`）。
- `SparseArray` 避免装箱整型键，面向几百条目。[Android SparseArray](https://developer.android.com/reference/kotlin/android/util/SparseArray)。**already-ruled**（`jp-android-sparse-array`）。
- 装箱流、正则、format 及其他 JVM slug 保持原样。本机没有能跑新 bench 的 JDK，故新 JVM 形态为 **no-compiler**。

## kotlinperf

- 传给非 inline 函数的 lambda 会分配闭包。`inline` 去掉该对象。[Kotlin inline functions](https://kotlinlang.org/docs/inline-functions.html)。**no-compiler**（此处无 `kotlinc`）。JVM 侧已有 `jp-lambda-to-non-inline-hot`。
- Android 上的 `SparseArray` 与 jvmperf 同一说明。JVM 侧 **already-ruled**，未为 Kotlin 重测。
- 字符串 `+`、`println` 与 `List` 增长在本 kit **already-ruled**。

## phpperf

- PHP 字符串可变。多参数 `echo` 可避免拼接。[Stack Overflow](https://stackoverflow.com/questions/124067/php-string-concatenation-performance)。循环里的 `.` **already-ruled**（`ph-string-dot-hot`）。
- 大数组 `implode` 在该 SitePoint 笔记里可能比追加用更多峰值内存。[SitePoint](https://www.sitepoint.com/high-performance-string-concatenation-in-php/)。**no-compiler**。

## dartperf

- 跨语言建串仓库含 Dart，并点名 `StringBuffer`。[langs_string_build_test](https://github.com/shagrouni/langs_string_build_test)。该仓库不是本树的受控 bench。循环字符串 `+` **already-ruled**（`dt-string-plus-hot`）。其余 Dart 形态 **no-compiler**。

## luaperf

- 收集行再 `table.concat` 在 Programming in Lua 里把 350 KB 读取从 40 秒降到 0.5 秒。[PIL 11.6](https://www.lua.org/pil/11.6.html)。**already-ruled**（`lu-string-concat-hot`）。本机无 `lua`，书中数字未重跑。超出该 slug 的均为 **no-compiler**。

## beamperf

- 二进制 `<>` 会拷贝。iolist 是块列表，IO 函数可直接写而不建单一二进制。[Elixir IO data](https://hexdocs.pm/elixir/1.18.4/IO.html) 与 [iolist 笔记](https://www.openmymind.net/Elixir-A-Little-Beyond-The-Basics-Part-2-iolist/)。循环列表拼接 **already-ruled**（`be-list-concat-reduce`）。本机无 Erlang/Elixir，新 iolist slug 为 **no-compiler**。

## nimperf

- 同一跨语言仓库计时 Nim 建串，未单独隔离 `setLen`。[langs_string_build_test](https://github.com/shagrouni/langs_string_build_test)。字符串 `&` 与 seq 增长 **already-ruled**。其余 Nim 形态 **no-compiler**。

## arktsperf

- 若 `+` 任一操作数是字符串，规范说表达式非常量时会创建新字符串对象。[ArkTS spec, additive expressions](https://yoyocat.github.io/ArkTSSpec/7_expressions.html)。本 kit 尚无 string-plus slug。**no-compiler**。不要把 JavaScript 计时抄到 ArkTS。
- 循环分配、`delete`、`console`、`includes` 与 JSON 均 **already-ruled**。
