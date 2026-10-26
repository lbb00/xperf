## 15. jvmperf-lint：自动找出反模式

`jvmperf-lint/` 是本指南配套的静态检查器：Java + tree-sitter（JVM 绑定 `io.github.bonede:tree-sitter`，以及 `tree-sitter-java` / `tree-sitter-kotlin`），同时支持 `.java`、`.kt`、`.kts`。它只看语法树，**不做类型解析**，所以快、零配置、不需要编译项目，但会有误报/漏报（每条规则都写明了误报风险）。完整说明见 [`jvmperf-lint/README.md`](../../jvmperf-lint/README.md)。

```sh
cd jvmperf-lint
./gradlew jar
bin/jvmperf-lint path/to/src          # 文本输出；有发现时退出码 1
bin/jvmperf-lint -f json --disable jp-finalize,jp-ui-text-append src
```

### 15.1 规则一览

默认级别为 `error`、`hint` 或 `off`，与 `bin/jvmperf-lint --list-rules` 的输出一致。标为 `off` 的规则默认不运行，需用 `--enable` 选中。

| 编号 | 名字 | 默认级别 | 语言 | 检查什么 | 对应章节 |
|---|---|---|---|---|---|
| jp-boxed-primitive-collection | boxed-primitive-collection | off | J/K | `List<Integer>`、`Map<Long,…>`、Kotlin `List<Int>`/`Array<Int>`/`HashMap<Int,…>` | 3、7.1 |
| jp-string-concat-in-loop | string-concat-in-loop | error | J/K | 循环内 `s += x` / `s = s + x` | 6.2 |
| jp-regex-in-loop | regex-in-loop | off | J/K | 循环内 `Pattern.compile`、`Regex(…)`、`replaceAll`、非快路径 `split` | 6.3 |
| jp-format-in-loop | format-in-loop | off | J/K | 循环内 `String.format` / `.formatted` / Kotlin `.format` | 6.4 |
| jp-unpresized-collection | unpresized-collection | off | J/K | 无初始容量的集合 / `StringBuilder` 在循环中填充 | 5.2 |
| jp-boxed-stream | boxed-stream | error | J | `Stream<Integer>` 上 `reduce(0, Integer::sum)`、`Collectors.summingInt` | 3.1 |
| jp-exception-control-flow | exception-control-flow | off | J/K | 循环里 try/catch 解析异常做判断 | 9.5 |
| jp-legacy-synchronized-type | — | **removed** | — | measured ~1.08×; see `evidence/_removed/` | — |
| jp-many-boolean-fields | — | **removed** | — | COH no win; see `evidence/_removed/` | — |
| jp-enum-key-hash-collection | enum-key-hash-collection | error | J/K | 枚举键 `HashMap` / 枚举元素 `HashSet` | 5.3 |
| jp-collection-chain | collection-chain | off | K | ≥ 3 步 `map/filter/…` 链，或 2 步 + 短路终止（`first`/`take`/`any`…） | 7.4 |
| jp-value-class-boxing | value-class-boxing | hint | K | value class 用作可空 / 泛型 / 数组元素 | 7.2 |
| jp-lambda-to-non-inline-in-loop | lambda-to-non-inline-in-loop | off | K | 循环里把 lambda 传给本文件中的非 inline 高阶函数 | 7.3 |
| jp-lazy-default-mode | lazy-default-mode | off | K | `by lazy { }` 未指定模式 | 7.5 |
| jp-data-copy-in-loop | data-copy-in-loop | error | K | 循环里 `copy(…)` | 7.7 |
| jp-android-sparse-array | android-sparse-array | hint | J/K | Android 文件中 `HashMap<Integer/Long, …>` | 12.2 |
| jp-log-in-loop | log-in-loop | off | J/K | 循环内 `System.out.println`、`Log.d/v`、未判断级别的日志 | 12.5 |
| jp-sleep-polling | sleep-polling | off | J/K | `while` 里只有 `Thread.sleep` + 条件检查的纯轮询 | 10 |
| jp-finalize | finalize | hint | J/K | 重写 `finalize()` | 9 |
| jp-expensive-alloc-in-loop | expensive-alloc-in-loop | off | J/K | 循环内 `new SimpleDateFormat/Random/ObjectMapper/MessageDigest/…`、常量大小 ≥ 256 的数组 | 10.3 |
| jp-hot-heavy-alloc | hot-heavy-alloc | off | J/K | 热上下文里 `Paint()`/`Path()`/`Rect()`/`Canvas()`/`Matrix()`、`Bitmap.createBitmap`、无容量的 `ByteArrayOutputStream()` | 5.2、12.5 |
| jp-hot-format-log | hot-format-log | off | J/K | 逐事件回调里的 `String.format` / `"%.2f".format` / 拼接的 `Log` 消息（循环内的归 jp-format-in-loop/jp-log-in-loop） | 6.4、12.5 |
| jp-hot-system-call | hot-system-call | hint | J/K | 热上下文里 `getSystemService`、`getRealMetrics`、`getEnabledAccessibilityServiceList`、PackageManager 查询、`Settings.*.get*`、`Toast.makeText` | 12.1 |
| jp-bitmap-decode-no-reuse | bitmap-decode-no-reuse | hint | J/K | 热上下文里 `BitmapFactory.decode*` 没有 `inBitmap` 复用 | 12.2、10.3 |
| jp-hot-post-lambda | hot-post-lambda | hint | J/K | 每个事件 `post { }` / `runOnUiThread { }` 一个新 lambda | 7.3 |
| jp-ui-text-append | ui-text-append | hint | J/K | `tv.text = 新行 + tv.text`（每次复制并重排全文，不要求热上下文） | 6.2 |
| jp-baos-tobytearray-copy | baos-tobytearray-copy | error | J/K | 热上下文里 `ByteArrayOutputStream.toByteArray()` 的额外整块复制 | 8.3 |
| jp-hot-payload-copy | hot-payload-copy | error | J/K | 热上下文里按 `payload.size` 新建缓冲再整体 `put(payload)`/`copyInto`/`arraycopy` | 8.2、8.3 |
| jp-client-factory-recreate | client-factory-recreate | error | J/K | 在短生命周期或循环内重复新建 OkHttpClient / Retrofit 这类工厂对象，而不是复用 | 10 |
| jp-string-intern-in-loop | string-intern-in-loop | error | J/K | 循环内调用 `String.intern()` | 6 |
| jp-non-static-field-updater | non-static-field-updater | hint | Java | 非 `static` 的 `Atomic*FieldUpdater` 字段 | 9 |

忽略：`// jvmperf-lint: ignore jp-boxed-primitive-collection,jp-string-concat-in-loop -- 原因`（作用于本行和下一行），`// jvmperf-lint: ignore-file jp-regex-in-loop`。本指南 `examples/` 中故意保留的反例都用这种注释标注了。

**热上下文（v0.3）**：jp-hot-heavy-alloc–jp-hot-payload-copy 不只看语法循环，而是给每个位置推断一个“热原因”，写在消息末尾 `[热: …]`：非周期循环；逐事件回调（`onTouch`、`onDraw`、`onBindViewHolder`、`doFrame`、`onImageAvailable` 等，`--hot-callbacks` 可追加）；注册给回调的 lambda（`setOnTouchListener { }`、`setOnImageAvailableListener`、`postFrameCallback`、`collect { }`）；名字像逐帧/逐包的参数或属性（`onFrame = { }`、`onJpeg = { }`）；用户标注（`// jvmperf-lint: hot`、`@HotPath`、`--hot-fn 正则`）；再沿调用传播（本文件两层，跨文件 `Obj.f()` 一层），例如 `[热: controlLoop:循环@404 → writeFrame → encode]`。周期循环（`sleep(≥500)` 或 interval/backoff 类变量）、`accept()` 循环和 `catch` 块不算热；jp-hot-format-log/jp-hot-post-lambda 跳过采样分支（`% NN`、`isLoggable`、`BuildConfig.DEBUG`、`== ACTION_DOWN`）。这些规则参考了 Android 投屏代码评审中发现的逐触摸 Binder 调用和 Toast、逐帧 `Bitmap`/`Canvas`/`ByteArrayOutputStream` 分配、日志区 `text = 新 + 旧`、逐帧整帧复制等问题。

### 15.2 夹具与测试

`fixtures/bad/` 与 `fixtures/good/` 下每条规则都有 Java 和/或 Kotlin 夹具（各 51 个文件，能被 javac 25 / kotlinc 2.4.21 编译，Android 夹具对 `android.jar` 编译）。`./gradlew test` 验证：每个 bad 夹具触发其规则（并且用 `--enable` 单独启用时也触发）、good 夹具 0 发现、忽略注释、JSON 格式、退出码、启动脚本，以及热上下文的跨文件原因链（`fixtures/hot_xfile/`）和 `--hot-fn`。

**【本机实测】输出示例**（v0.3 的输出；jp-regex-in-loop 现在默认为 `off`，需加 `--enable jp-regex-in-loop` 才会报告）：

```text
$ bin/jvmperf-lint fixtures/bad/jp-regex-in-loop.java fixtures/bad/jp-value-class-boxing.kt
fixtures/bad/jp-regex-in-loop.java:6:17: warning[jp-regex-in-loop regex-in-loop] 循环内编译正则表达式 / regular expression compiled inside a loop: Pattern.compile(...)
    建议: 把 Pattern.compile / Regex(...) 提为 static final / companion 常量；String.replaceAll/replaceFirst/matches 每次都会编译正则，字面替换用 replace(CharSequence)
fixtures/bad/jp-regex-in-loop.java:7:18: warning[jp-regex-in-loop regex-in-loop] ...: .split("\\s+")：非单字符快路径，每次编译正则
fixtures/bad/jp-regex-in-loop.java:8:13: warning[jp-regex-in-loop regex-in-loop] ...: .replaceAll(...)：每次调用都编译正则
fixtures/bad/jp-value-class-boxing.kt:4:26: info[jp-value-class-boxing value-class-boxing] ...: UserId?：可空的 value class 被装箱
fixtures/bad/jp-value-class-boxing.kt:5:14: info[jp-value-class-boxing value-class-boxing] ...: List<UserId>：泛型参数中的 UserId 被装箱
fixtures/bad/jp-value-class-boxing.kt:5:29: info[jp-value-class-boxing value-class-boxing] ...: Array<UserId>：数组元素被装箱
```

全部 bad 夹具：50 个文件 76 处发现（v0.3），每个文件都触发了自己的规则；good 夹具：0 处。在 JDK 25 自带源码 `java.base/java/{util,text,io}`（506 个文件）上的抽查结果见 `research/jdk-src-precision.txt`。

### 15.3 与现有开源工具的对比

jvmperf-lint 不是要替代成熟工具，而是补上"Kotlin 专属的分配/装箱问题"和"跨 Java/Kotlin 统一的循环内反模式"这两块。下表把我们的规则映射到其他工具中**已核对过文档**的等价规则（链接均已于 2026-10-21 访问验证）。

#### 各工具概览

| 工具 | 类型 | 覆盖什么（与性能相关的部分） | 是否需要编译/类型信息 |
|---|---|---|---|
| [PMD](https://pmd.github.io/)（7.28.0）[performance 规则集](https://docs.pmd-code.org/latest/pmd_rules_java_performance.html) | Java 源码静态分析 | `UseStringBufferForStringAppends`、`AvoidInstantiatingObjectsInLoops`、`UseArrayListInsteadOfVector`、`InsufficientStringBufferDeclaration`、`AvoidFileStream`、`OptimizableToArrayCall`、`AddEmptyString`、`InefficientEmptyStringCheck` 等约 20 条；另有 bestpractices 中的 `ReplaceVectorWithList`、`ReplaceHashtableWithMap`、`AvoidStringBufferField`，errorprone 中的 finalize 系列 | 源码；类型解析需 auxclasspath |
| [SpotBugs](https://spotbugs.github.io/)（4.10.5）[PERFORMANCE 类别](https://spotbugs.readthedocs.io/en/latest/bugDescriptions.html) | 字节码分析 | `SBSC_USE_STRINGBUFFER_CONCATENATION`、`IIL_PATTERN_COMPILE_IN_LOOP(_INDIRECT)`、`DM_BOXED_PRIMITIVE_*`、`BX_*` 装箱拆箱、`WMI_WRONG_MAP_ITERATOR`、`SIC_INNER_SHOULD_BE_STATIC`、`DM_STRING_CTOR`、`DMI_RANDOM_USED_ONLY_ONCE`（在 BAD_PRACTICE 中）、`FI_*` finalize 系列 | 需要编译后的 .class；Kotlin 字节码也能分析，但误报多 |
| [find-sec-bugs](https://find-sec-bugs.github.io/bugs.htm)（1.14.0） | SpotBugs 安全插件 | 安全规则；与性能唯一沾边的是 `REDOS`（灾难性回溯正则） | 同 SpotBugs |
| [Error Prone](https://errorprone.info/bugpatterns)（2.50.0） | javac 插件 | [`JdkObsolete`](https://errorprone.info/bugpattern/JdkObsolete)（LinkedList/Vector/Hashtable/Stack/StringBuffer）、[`UnnecessaryBoxedVariable`](https://errorprone.info/bugpattern/UnnecessaryBoxedVariable)、[`UnnecessaryBoxedAssignment`](https://errorprone.info/bugpattern/UnnecessaryBoxedAssignment)、[`BoxedPrimitiveConstructor`](https://errorprone.info/bugpattern/BoxedPrimitiveConstructor)、[`Finalize`](https://errorprone.info/bugpattern/Finalize)、[`UnnecessaryStringBuilder`](https://errorprone.info/bugpattern/UnnecessaryStringBuilder) | 编译期，有完整类型；仅 Java |
| [detekt](https://detekt.dev/)（稳定版 1.23.8；2.0 在 alpha）[performance 规则集](https://detekt.dev/docs/rules/performance/) | Kotlin 静态分析 | `ArrayPrimitive`、`CouldBeSequence`（默认关闭）、`ForEachOnRange`、`SpreadOperator`、`UnnecessaryTemporaryInstantiation`、`UnnecessaryTypeCasting`、（2.0）`UnnecessaryInitOnArray`、`UnnecessaryPartOfBinaryExpression` | 部分规则需类型解析（`--classpath`） |
| [Android Lint](https://developer.android.com/studio/write/lint)（[检查列表](https://googlesamples.github.io/android-custom-lint-rules/checks/index.md.html)） | Android 项目分析 | [`UseSparseArrays`](https://googlesamples.github.io/android-custom-lint-rules/checks/UseSparseArrays.md.html)、[`UseValueOf`](https://googlesamples.github.io/android-custom-lint-rules/checks/UseValueOf.md.html)、[`DrawAllocation`](https://googlesamples.github.io/android-custom-lint-rules/checks/DrawAllocation.md.html)、[`LogConditional`](https://googlesamples.github.io/android-custom-lint-rules/checks/LogConditional.md.html)（默认关闭）、[`Recycle`](https://googlesamples.github.io/android-custom-lint-rules/checks/Recycle.md.html)、[`ViewHolder`](https://googlesamples.github.io/android-custom-lint-rules/checks/ViewHolder.md.html) 等 Performance 类别 | 需要 Android 项目模型（通常经 AGP） |
| [ktlint](https://github.com/pinterest/ktlint)（1.8.0，[规则](https://ktlint.github.io/ktlint/latest/rules/standard/)） | Kotlin 格式化/风格 | **只管代码风格**，没有性能规则 | 否 |
| [SonarQube / SonarLint（SonarQube for IDE）](https://www.sonarsource.com/products/sonarlint/)，[sonar-java](https://github.com/SonarSource/sonar-java) 8.44 | 多语言平台 | Java：[S1643](https://rules.sonarsource.com/java/rspec-1643/) 循环内字符串拼接、[S1149](https://rules.sonarsource.com/java/rspec-1149/) 同步遗留类、[S4248](https://rules.sonarsource.com/java/rspec-4248/) 正则不必要地重复编译、[S1640](https://rules.sonarsource.com/java/rspec-1640/) 枚举键用 EnumMap、[S1641](https://rules.sonarsource.com/java/rspec-1641/) 枚举集合用 EnumSet 等；Kotlin 规则以代码异味/缺陷为主 | 需要编译产物做完整分析 |
| [Checkstyle](https://checkstyle.org/checks.html)（14.3.0） | Java 风格 | 没有性能类别；[`NoFinalizer`](https://checkstyle.org/checks/coding/nofinalizer.html)，以及可配置的 [`IllegalInstantiation`](https://checkstyle.org/checks/coding/illegalinstantiation.html) / [`IllegalType`](https://checkstyle.org/checks/coding/illegaltype.html)（可用来禁用 `Vector`、`Hashtable`、`HashMap` 等） | 否 |
| IntelliJ IDEA 检查（[Java › Performance](https://www.jetbrains.com/help/inspectopedia/Java-Performance.html)） | IDE | 约 40 条：[字符串循环拼接](https://www.jetbrains.com/help/inspectopedia/StringContatenationInLoop.html)、[循环内分配对象](https://www.jetbrains.com/help/inspectopedia/ObjectAllocationInLoop.html)、[集合无初始容量](https://www.jetbrains.com/help/inspectopedia/CollectionWithoutInitialCapacity.html)、[动态正则可换成预编译 Pattern](https://www.jetbrains.com/help/inspectopedia/DynamicRegexReplaceableByCompiledPattern.html)、[EnumMap](https://www.jetbrains.com/help/inspectopedia/MapReplaceableByEnumMap.html)/[EnumSet](https://www.jetbrains.com/help/inspectopedia/SetReplaceableByEnumSet.html)、[自动装箱](https://www.jetbrains.com/help/inspectopedia/boxing.html)、[Busy wait](https://www.jetbrains.com/help/inspectopedia/BusyWait.html)；Kotlin：[集合调用链可转为 Sequence](https://www.jetbrains.com/help/inspectopedia/ConvertCallChainIntoSequence.html) | IDE 内有完整类型；可用 `inspect.sh` 无界面运行，但依赖 IDE 安装 |
| [OpenRewrite](https://docs.openrewrite.org/recipes)（rewrite-static-analysis 2.45.0） | 自动重构配方 | 不报告而是**改代码**：[`UseStringReplace`](https://docs.openrewrite.org/recipes/staticanalysis/usestringreplace)、[`ReplaceStackWithDeque`](https://docs.openrewrite.org/recipes/staticanalysis/replacestackwithdeque)、[`PrimitiveWrapperClassConstructorToValueOf`](https://docs.openrewrite.org/recipes/staticanalysis/primitivewrapperclassconstructortovalueof)、[`NoFinalizer`](https://docs.openrewrite.org/recipes/staticanalysis/nofinalizer)、[`RemoveCallsToObjectFinalize`](https://docs.openrewrite.org/recipes/staticanalysis/removecallstoobjectfinalize)、[`RemoveCallsToSystemGc`](https://docs.openrewrite.org/recipes/staticanalysis/removecallstosystemgc)；以及版本迁移配方（如 [UpgradeToJava25](https://docs.openrewrite.org/recipes/java/migrate/upgradetojava25)） | 需要构建插件 + 类型信息 |
| 运行时工具：[JOL](https://github.com/openjdk/jol)、[JFR](https://docs.oracle.com/en/java/javase/25/jfapi/)、[async-profiler](https://github.com/async-profiler/async-profiler)、[JMH](https://github.com/openjdk/jmh) | 测量 | 不找"写法问题"，而是告诉你**真实的**对象大小、分配热点、CPU 热点和耗时。静态工具（包括本工具）的每条提示都应由它们确认是否值得修 | 运行程序 |

#### 规则映射（我们的规则 → 已有的等价规则）

| jvmperf-lint | PMD | SpotBugs | Error Prone | detekt | Android Lint | Sonar（Java） | IntelliJ | OpenRewrite | 仍由本工具补充的部分 |
|---|---|---|---|---|---|---|---|---|---|
| jp-boxed-primitive-collection 装箱集合 | — | 仅 `BX_*`（局部装箱拆箱） | `UnnecessaryBoxedVariable`（局部变量） | `ArrayPrimitive`（仅 `Array<Int>` 等） | — | — | `boxing`（逐表达式） | — | Java 泛型集合 + Kotlin `List<Int>`/`HashMap<Int,…>` 字段/变量类型层面的提示 |
| jp-string-concat-in-loop 循环拼接 | `UseStringBufferForStringAppends` | `SBSC_USE_STRINGBUFFER_CONCATENATION` | — | — | — | S1643 | `StringContatenationInLoop` | — | **Kotlin** 的 `s += "$x"` |
| jp-regex-in-loop 循环内正则 | — | `IIL_PATTERN_COMPILE_IN_LOOP(_INDIRECT)` | （`StringSplitter` 管语义不管性能） | — | — | S4248（不限循环） | `DynamicRegexReplaceableByCompiledPattern` | `UseStringReplace` | Kotlin `Regex(...)`/`toRegex()` 在循环内；`split` 快路径判断 |
| jp-format-in-loop 循环内 format | — | — | — | — | — | — | — | — | 全部 |
| jp-unpresized-collection 未预设容量 | `InsufficientStringBufferDeclaration`（仅 StringBuilder） | — | — | — | — | — | `CollectionWithoutInitialCapacity`、`StringBufferWithoutInitialCapacity` | — | 仅在"循环中填充"时报告，Kotlin 同样适用 |
| jp-boxed-stream 装箱 Stream 归约 | — | — | — | — | — | — | — | — | 全部（启发式） |
| jp-exception-control-flow 异常做控制流 | `ExceptionAsFlowControl`（仅本方法内 throw 后 catch） | — | — | — | — | — | `ThrowCaughtLocally`（同上） | — | 循环里"try 解析 + catch 判断"模式，Java/Kotlin |
| jp-legacy-synchronized-type 遗留同步类型（规则已移除） | `ReplaceVectorWithList`、`ReplaceHashtableWithMap`、`UseArrayListInsteadOfVector`、`AvoidStringBufferField` | — | `JdkObsolete` | — | — | S1149 | `UseOfObsoleteCollectionType` | `ReplaceStackWithDeque`（仅 Stack） | Kotlin 中的 `Vector()`/`StringBuffer()` |
| jp-many-boolean-fields 多个 boolean 字段（规则已移除） | — | — | — | — | — | — | — | — | 全部 |
| jp-enum-key-hash-collection 枚举键哈希集合 | — | — | — | — | — | S1640、S1641 | `MapReplaceableByEnumMap`、`SetReplaceableByEnumSet` | — | Kotlin `HashMap<Color,…>()`/`mutableMapOf<Color,…>()` |
| jp-collection-chain 集合链 | — | — | — | `CouldBeSequence`（默认关闭，需类型解析） | — | — | `ConvertCallChainIntoSequence` | — | 无需类型解析、命令行可用 |
| jp-value-class-boxing value class 装箱 | — | — | — | — | — | — | — | — | 全部 |
| jp-lambda-to-non-inline-in-loop 非 inline 高阶函数 + lambda | — | — | — | — | — | — | — | — | 全部（限同文件声明） |
| jp-lazy-default-mode `by lazy` 默认模式 | — | — | — | — | — | — | — | — | 全部 |
| jp-data-copy-in-loop 循环内 `copy()` | — | — | — | — | — | — | — | — | 全部 |
| jp-android-sparse-array SparseArray | — | — | — | — | `UseSparseArrays` | — | （Android 插件同一检查） | — | 不需要 Android 项目模型 |
| jp-log-in-loop 循环内日志 | `SystemPrintln`（bestpractices，不限循环） | — | — | — | `LogConditional`（仅 `Log.d/v`，默认关闭） | — | — | — | 循环 + `System.out` + 已判断级别时不报 |
| jp-sleep-polling sleep 轮询 | — | — | — | — | — | — | `BusyWait` | — | Kotlin |
| jp-finalize finalize | `FinalizeOnlyCallsSuperFinalize` 等 finalize 系列 | `FI_*` | `Finalize` | — | — | — | `FinalizeDeclaration` | `NoFinalizer` | Kotlin `protected fun finalize()` |
| jp-expensive-alloc-in-loop 循环内昂贵分配 | `AvoidInstantiatingObjectsInLoops`（任何 `new`，噪声大） | `DMI_RANDOM_USED_ONLY_ONCE`（部分） | — | — | `DrawAllocation`（仅 `onDraw` 等） | — | `ObjectAllocationInLoop`（任何分配） | — | 只报"昂贵/可复用"类型与 ≥256 字节的常量数组，降低噪声 |

反过来，**这些工具覆盖而 jvmperf-lint 没有的**：PMD 的 `OptimizableToArrayCall`、`AvoidFileStream`、`InefficientEmptyStringCheck`、`AddEmptyString`；SpotBugs 的 `WMI_WRONG_MAP_ITERATOR`、`SIC_INNER_SHOULD_BE_STATIC`、`DM_STRING_CTOR`；detekt 的 `SpreadOperator`、`ForEachOnRange`、`UnnecessaryTemporaryInstantiation`；Android Lint 的 `DrawAllocation`、`Recycle`、`ViewHolder`；IntelliJ 的 `KeySetIterationMayUseEntrySet`、`ManualArrayCopy` 等。**推荐组合**：Java 用 Error Prone 或 PMD（CI）+ IntelliJ 检查（编辑时），Kotlin 用 detekt（打开 `CouldBeSequence`），Android 加 Android Lint；jvmperf-lint 作为不需要编译、同时覆盖 Java/Kotlin 的补充，最后用 JFR/async-profiler/JMH 确认哪些提示值得修。

### 15.4 实测：PMD 和 detekt 跑在同一批 bad 夹具上

两者都是单个小下载、不需要 Gradle 缓存，所以在本机实际跑了一遍（跑完已删除工具本体，输出保存在 `research/`）。

**PMD 7.28.0**（`pmd check --use-version java-25`，规则集 = 整个 `category/java/performance.xml` + 10 条相关规则，见 `research/pmd-ruleset-compare.xml`；完整输出 `research/pmd-on-fixtures.txt`）在 15 个 Java bad 夹具上：

| 夹具 | PMD 报告 | jvmperf-lint |
|---|---|---|
| jp-string-concat-in-loop | `UseStringBufferForStringAppends` | ✅ |
| jp-legacy-synchronized-type（规则已移除） | `ReplaceVectorWithList` ×2、`UseArrayListInsteadOfVector`、`ReplaceHashtableWithMap` ×2 | ✅ |
| jp-finalize | `FinalizeOnlyCallsSuperFinalize` | ✅ |
| jp-expensive-alloc-in-loop | `AvoidInstantiatingObjectsInLoops` ×3 | ✅ |
| jp-exception-control-flow | 只有 `EmptyCatchBlock`（与性能无关的附带发现） | ✅ |
| jp-enum-key-hash-collection | 只有 `UseConcurrentHashMap`（不相关） | ✅ |
| jp-boxed-primitive-collection、jp-regex-in-loop、jp-format-in-loop、jp-unpresized-collection、jp-boxed-stream、jp-many-boolean-fields（规则已移除）、jp-android-sparse-array、jp-log-in-loop、jp-sleep-polling | 无 | ✅ |

在 good 夹具上 PMD 报了 2 处：`good/jp-expensive-alloc-in-loop.java` 中按天数分配的 `new int[d.getDayOfMonth()]`（`AvoidInstantiatingObjectsInLoops`），`good/jp-enum-key-hash-collection.java` 中普通的 `HashMap<String,String>` 字段（`UseConcurrentHashMap`）。也就是说：PMD 在 Java 侧与我们重叠 4 条规则（jp-string-concat-in-loop/008/019/020），`AvoidInstantiatingObjectsInLoops` 比 jp-expensive-alloc-in-loop 宽得多（任何 `new` 都报）；注意 PMD 的 performance 规则集**没有**循环内正则检查（SpotBugs 和 Sonar 有）。

**detekt 1.23.8**（`detekt-cli-1.23.8-all.jar`，JDK 21 运行；默认配置 + 启用 `CouldBeSequence`，关闭 `MagicNumber`/`MatchingDeclarationName` 两条风格噪声；`--classpath kotlin-stdlib-1.9.22.jar` 做类型解析；完整输出 `research/detekt-on-fixtures.txt`）在 19 个 Kotlin bad 夹具上：

| 夹具 | detekt 报告 | jvmperf-lint |
|---|---|---|
| jp-boxed-primitive-collection.kt | `ArrayPrimitive` ×2（只针对 `Array<Long>`/`arrayOf(1L)`；`List<Int>`、`HashMap<Int,Int>` 未报） | ✅（3 处） |
| jp-collection-chain.kt | `CouldBeSequence`（只报了 3 步的 `pipeline`；2 步的 `map.filter.firstOrNull` 低于默认阈值） | ✅（2 处） |
| jp-exception-control-flow.kt / jp-finalize.kt | 只有 `EmptyCatchBlock` / `EmptyFunctionBlock`（附带发现） | ✅ |
| 其余 15 个（含 jp-value-class-boxing value class 装箱、jp-lambda-to-non-inline-in-loop、jp-lazy-default-mode、jp-data-copy-in-loop、jp-string-concat-in-loop Kotlin 拼接、jp-regex-in-loop Kotlin 正则等） | 无 | ✅ |

good 夹具上 detekt 只报了一处 `EmptyFunctionBlock`（`close() {}`）。为了确认 detekt 的规则本身工作正常，另用 `research/detekt-probe.kt` 验证了 `ForEachOnRange`、`SpreadOperator`、`CouldBeSequence` 都能触发（`research/detekt-probe-out.txt`）——这三条中前两条是 jvmperf-lint 没有的。备注：用 kotlinc 2.4.21 自带的 stdlib 做类型解析时 `CouldBeSequence` 没有触发，换成 1.9.22 的 stdlib 并在配置里显式启用后触发；detekt 1.23.x 内置的是 Kotlin 2.0.21 编译器。

**Android Lint**（Android SDK cmdline-tools 自带的 `lint` 8.2.0，无 Gradle 项目，`--sources` 模式）：在一个探针文件上 `LogConditional`（需 `--enable`）与 `UseValueOf` 正常触发，但 `UseSparseArrays` 对 `new HashMap<Integer, String>()` 没有报告——很可能是独立 CLI 模式缺少 AGP 提供的项目模型，所以**这里不对 Android Lint 的覆盖率下结论**（`research/android-lint-probe.txt`）。

**没有实际运行的**：SpotBugs（需要先编译出 .class，且 Kotlin 字节码误报多）、Error Prone（需要接入 javac 插件路径）、SonarQube（需要服务器）、IntelliJ（需要 IDE 安装）、OpenRewrite（需要 Maven/Gradle 插件与依赖缓存）、Checkstyle（无性能规则）、ktlint（无性能规则）。这些工具的映射基于其官方文档。

### 15.5 证据门槛与 HotSpot 对照

规则必须同时有 `evidence/<RULE>.md` 和 `evidence/<RULE>.jsonl`（见 [`docs/evidence-policy.md`](../evidence-policy.md)），才可能升到 **error**；在此之前，lint 的发现只是供人复查的提示。按当前的默认级别，**error** 共 8 条：jp-string-concat-in-loop、jp-boxed-stream、jp-enum-key-hash-collection、jp-data-copy-in-loop、jp-baos-tobytearray-copy、jp-hot-payload-copy、jp-client-factory-recreate、jp-string-intern-in-loop。另有 11 条规则有 JSONL 但默认低于 error：**hint** 为 jp-value-class-boxing、jp-non-static-field-updater；**off** 为 jp-boxed-primitive-collection、jp-regex-in-loop、jp-format-in-loop、jp-unpresized-collection、jp-exception-control-flow、jp-collection-chain、jp-lambda-to-non-inline-in-loop、jp-log-in-loop、jp-expensive-alloc-in-loop。其余 10 条只有 md 占位（多数需要 ART 或真机）：jp-lazy-default-mode、jp-android-sparse-array、jp-sleep-polling、jp-finalize、jp-hot-heavy-alloc、jp-hot-format-log、jp-hot-system-call、jp-bitmap-decode-no-reuse、jp-hot-post-lambda、jp-ui-text-append。

交叉验证：`scripts/run-static-vs-hotspot.sh` 的输出写在 `research/benches/`。**静态 lint 不等于 HotSpot 的判断**：不能只看源码就断言 C2 的编译层级或逃逸分析失败，也不要用 PrintCompilation 的行数当作“一致/不一致”的判据。

---

