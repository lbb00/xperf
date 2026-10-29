package com.jvmperf.lint;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

public record Rule(
        String code,
        String name,
        String severity,
        List<String> langs,
        String msgZh,
        String msgEn,
        String fix,
        String fpRisk
) {
    public static final String JAVA = "java";
    public static final String KOTLIN = "kotlin";

    public static final List<Rule> RULES = List.of(
            r("jp-boxed-primitive-collection", "boxed-primitive-collection", "off", List.of(JAVA, KOTLIN),
                    "集合/数组的元素是装箱的原始类型", "collection or array of boxed primitives",
                    "每个元素是一个独立对象（JDK 25 默认 16 字节 + 4 字节引用）；改用 int[]/IntArray，或 fastutil / Eclipse Collections / androidx.collection 的原始类型集合",
                    "中：小集合、或需要 null / 泛型 API 时装箱是合理的"),
            r("jp-string-concat-hot", "string-concat-hot", "error", List.of(JAVA, KOTLIN),
                    "循环内用 += / + 拼接字符串", "string concatenation with += inside a loop",
                    "每次迭代复制整个字符串，O(n²)；循环外创建 StringBuilder（预设容量）/ buildString { }，循环内 append",
                    "低：只在变量被声明为 String 或以字符串字面量初始化时报告"),
            r("jp-regex-hot", "regex-hot", "off", List.of(JAVA, KOTLIN),
                    "循环内编译正则表达式", "regular expression compiled inside a loop",
                    "把 Pattern.compile / Regex(...) 提为 static final / companion 常量；String.replaceAll/replaceFirst/matches 每次都会编译正则，字面替换用 replace(CharSequence)",
                    "低：String.split 只在参数不是单字符快路径时报告"),
            r("jp-format-hot", "format-hot", "off", List.of(JAVA, KOTLIN),
                    "循环内调用 String.format / formatted", "String.format / formatted called inside a loop",
                    "String.format 每次都要解析格式串并创建 Formatter；热路径用 StringBuilder.append，或循环外复用 Formatter",
                    "中：低频循环（如每次迭代都有 I/O）中可以忽略"),
            r("jp-unpresized-collection", "unpresized-collection", "off", List.of(JAVA, KOTLIN),
                    "集合/StringBuilder 未预设容量就在循环中填充", "collection or StringBuilder filled in a loop without initial capacity",
                    "已知元素个数时预设容量：new ArrayList<>(n)、HashMap.newHashMap(n)（JDK 19+）、ArrayList<T>(n)、StringBuilder(cap)",
                    "中：元素个数无法预估或通常很少时可忽略"),
            r("jp-boxed-stream", "boxed-stream", "error", List.of(JAVA),
                    "Stream 在装箱的 Integer/Long/Double 上做数值归约", "numeric reduction on a boxed Stream",
                    "用 mapToInt / mapToLong / mapToDouble 转为 IntStream 等原始类型流，再 sum() / average() / summaryStatistics()",
                    "中：没有类型信息，只在调用链上能看到 .stream()/Stream.of 且没有 mapToInt 等转换时匹配 reduce(Integer::sum)/加法 lambda；Collectors.summingX/averagingX 总是报告"),
            r("jp-exception-control-flow", "exception-control-flow", "off", List.of(JAVA, KOTLIN),
                    "循环内用捕获异常来做流程控制", "exceptions used for control flow inside a loop",
                    "先检查再操作（边界判断、hasNext、Kotlin 的 toIntOrNull/getOrNull）；确需高频抛出时关闭栈追踪 super(msg, null, false, false)",
                    "中：低频错误输入处理是合理的；只有异常在正常迭代中反复发生时才值得优先处理"),
            r("jp-enum-key-hash-collection", "enum-key-hash-collection", "error", List.of(JAVA, KOTLIN),
                    "以枚举为键的 HashMap / HashSet", "HashMap / HashSet keyed by an enum",
                    "改用 EnumMap / EnumSet：内部是按 ordinal 索引的数组 / 位向量，无哈希、无 Entry 对象",
                    "低：只识别同一文件内声明的 enum"),
            r("jp-collection-chain", "collection-chain", "off", List.of(KOTLIN),
                    "大数据上的多步集合操作链，每一步都生成中间 List", "multi-step collection chain creates intermediate lists",
                    "数据量大或有提前终止（first/take/any）时用 asSequence() 流水线；小集合保持现状",
                    "中：小集合上集合操作反而比序列更快"),
            r("jp-value-class-boxing", "value-class-boxing", "hint", List.of(KOTLIN),
                    "value class 以可空/泛型/数组形式使用，会被装箱", "value class used as nullable / generic / array element is boxed",
                    "用哨兵值代替可空；大量元素用底层类型的原始数组（IntArray/LongArray）存储，读取时再包装",
                    "中：只识别同一文件内声明的 value class；低频路径无需在意"),
            r("jp-lambda-to-non-inline-hot", "lambda-to-non-inline-hot", "off", List.of(KOTLIN),
                    "循环内把 lambda 传给非 inline 的高阶函数", "lambda passed to a non-inline higher-order function inside a loop",
                    "给高阶函数加 inline；或改用原始类型签名的 fun interface，避免 Function1 的装箱",
                    "中：只识别同一文件内声明的函数；不捕获变量的 lambda 不会每次分配"),
            r("jp-lazy-default-mode", "lazy-default-mode", "off", List.of(KOTLIN),
                    "by lazy 未指定线程安全模式（默认 SYNCHRONIZED）", "by lazy without an explicit LazyThreadSafetyMode",
                    "只在单线程访问时用 lazy(LazyThreadSafetyMode.NONE)；初始化幂等时可用 PUBLICATION",
                    "高：多线程访问时默认模式才是正确的，请确认后再改"),
            r("jp-data-copy-hot", "data-copy-hot", "error", List.of(KOTLIN),
                    "循环内调用 data class 的 copy()", "data class copy() inside a loop",
                    "每次 copy 都新建对象；热循环用局部变量累积，最后构造一次",
                    "中：逃逸分析有时能消除分配；对象很小且循环次数少时无所谓"),
            r("jp-android-sparse-array", "android-sparse-array", "hint", List.of(JAVA, KOTLIN),
                    "Android 代码中以 Integer/Long 为键的 HashMap", "HashMap with Integer/Long keys in Android code",
                    "Android 上用 SparseArray / SparseIntArray / LongSparseArray / androidx.collection 的 IntObjectMap 等，避免键装箱和 Entry 对象",
                    "低-中：只在 import 了 android.* / androidx.* 的文件中检查；上千项且频繁增删时 HashMap 可能更快"),
            r("jp-log-hot", "log-hot", "off", List.of(JAVA, KOTLIN),
                    "循环中可能打印/记录日志", "logging call inside a loop",
                    "先确认日志是否会在正常迭代中反复触发；高频日志再移出循环、采样或先判断级别，System.out 可先缓冲后一次输出",
                    "高：仅凭语法无法判断日志是否只在异常/重试分支触发；低频循环或错误分支中的日志通常不在热路径"),
            r("jp-sleep-polling", "sleep-polling", "off", List.of(JAVA, KOTLIN),
                    "在 while 循环中用 Thread.sleep 轮询", "polling with Thread.sleep in a while loop",
                    "用阻塞原语等待事件：CountDownLatch、CompletableFuture、BlockingQueue.take、Condition、ScheduledExecutorService；协程中用 delay/Channel",
                    "低：只报“纯轮询”循环（循环体除 sleep、catch 和 if 条件外没有其他调用）；每轮有实际工作的心跳/信标/帧节拍/退避重连不报（v0.2 起）"),
            r("jp-finalize", "finalize", "hint", List.of(JAVA, KOTLIN),
                    "重写 finalize()", "overrides finalize()",
                    "终结机制已弃用待删除（JEP 421），且拖慢 GC；用 try-with-resources / use { } 或 java.lang.ref.Cleaner",
                    "低"),
            r("jp-expensive-alloc-hot", "expensive-alloc-hot", "off", List.of(JAVA, KOTLIN),
                    "循环内创建昂贵或可复用的对象", "expensive or reusable object created inside a loop",
                    "把 SimpleDateFormat / DateTimeFormatter / Random / ObjectMapper / Gson / MessageDigest / 缓冲数组 等提到循环外复用（注意线程安全）",
                    "中：数组只报告常量大小 ≥ 256 的；对象必须每次独立（如不可共享的 SimpleDateFormat 在多线程中）时是合理的"),
            r("jp-hot-heavy-alloc", "hot-heavy-alloc", "off", List.of(JAVA, KOTLIN),
                    "热上下文中分配重对象", "heavy object allocated in a hot context",
                    "Paint/Path/Rect/Canvas/Bitmap 等提为字段复用；ByteArrayOutputStream 预设容量并 reset() 复用；Bitmap 用池或 inBitmap",
                    "中：热上下文是推断的（回调名/传播/循环）；只在首次或低频分支里执行时可忽略"),
            r("jp-hot-format-log", "hot-format-log", "off", List.of(JAVA, KOTLIN),
                    "热回调中格式化字符串或拼接日志", "string formatting / log message building in a hot callback",
                    "去掉逐事件日志或只记 DOWN/UP；必要时用 Log.isLoggable 守卫；避免 String.format（解析格式串 + Formatter 分配）",
                    "低：循环内由 jp-format-hot/jp-log-hot 报告；采样分支（if (n % 30 == 0)）和 isLoggable 守卫下不报"),
            r("jp-hot-system-call", "hot-system-call", "hint", List.of(JAVA, KOTLIN),
                    "热上下文中调用系统服务/IPC", "system-service / IPC call in a hot context",
                    "getSystemService、getRealMetrics、getEnabledAccessibilityServiceList、PackageManager 查询、Settings.get*、Toast 都可能是 Binder 调用；缓存结果并监听变化",
                    "中：getSystemService 本身有缓存，但后续调用通常是 IPC"),
            r("jp-bitmap-decode-no-reuse", "bitmap-decode-no-reuse", "hint", List.of(JAVA, KOTLIN),
                    "热上下文中 BitmapFactory.decode* 未复用 Bitmap", "BitmapFactory.decode* in a hot context without inBitmap reuse",
                    "BitmapFactory.Options().apply { inMutable = true; inBitmap = reusable }，双/三缓冲；API 19+ 支持尺寸不大于 inBitmap 的复用",
                    "低：函数里出现 inBitmap 且传了 Options 就不报"),
            r("jp-hot-post-lambda", "hot-post-lambda", "hint", List.of(JAVA, KOTLIN),
                    "每个事件都 post 一个新的 lambda", "posting a fresh lambda/Runnable per event",
                    "合并：AtomicReference 存最新值 + 只在没有待处理任务时 post 一个复用的 Runnable；避免主线程消息堆积",
                    "中：低频事件无所谓"),
            r("jp-ui-text-append", "ui-text-append", "hint", List.of(JAVA, KOTLIN),
                    "把新内容拼到 TextView 旧文本上再整体 setText", "TextView text rebuilt by concatenating onto its old text",
                    "每次复制整个文本并重新排版；用环形缓冲保存最近 N 行、节流刷新（如 200ms 一次），或 TextView.append",
                    "低：只在右侧读取了同一控件的 text 时报告（不要求热上下文）"),
            r("jp-baos-tobytearray-copy", "baos-tobytearray-copy", "error", List.of(JAVA, KOTLIN),
                    "热上下文中 ByteArrayOutputStream.toByteArray() 额外复制", "ByteArrayOutputStream.toByteArray() copies the buffer in a hot context",
                    "用 baos.writeTo(out) 直接写出，或继承 ByteArrayOutputStream 暴露 buf/count，复用一个预设容量的实例",
                    "中：结果需要被长期持有时复制是必要的"),
            r("jp-hot-payload-copy", "hot-payload-copy", "error", List.of(JAVA, KOTLIN),
                    "热上下文中按负载大小新建缓冲并整体复制", "new buffer sized by a payload and the whole payload copied in a hot context",
                    "先写固定长度头部再直接写 payload（BufferedOutputStream / GatheringByteChannel），避免每帧整帧复制",
                    "中：需要连续内存（如一次 DatagramPacket）时复制是必要的"),
            r("jp-client-factory-recreate", "client-factory-recreate", "error", List.of(JAVA, KOTLIN),
                    "短生命周期或循环内新建 OkHttpClient / Retrofit", "OkHttpClient / Retrofit created in a loop or short-lived scope",
                    "把 OkHttpClient / Retrofit 提为单例或字段复用；每次 new 都会新建连接池与线程，泄漏并放大延迟（Retrofit#1401 / OkHttp#4337）",
                    "中：测试/示例中的一次性构造可忽略；Builder 配置后 build() 一次再共享"),
            r("jp-string-intern-hot", "string-intern-hot", "error", List.of(JAVA, KOTLIN),
                    "循环内调用 String.intern()", "String.intern() called inside a loop",
                    "intern 表是全局的且只增不减；热路径用自有 Map/Interner（Guava Interners.newWeakInterner）或直接比较内容",
                    "中：一次性启动加载表可以接受；循环内逐条 intern 通常是误用"),
            r("jp-non-static-field-updater", "non-static-field-updater", "hint", List.of(JAVA),
                    "Atomic*FieldUpdater 字段不是 static", "Atomic*FieldUpdater field is not static",
                    "每个 updater 实例都持有类/字段元数据；必须为 static final（见 Guava #7606 / Shipilev）",
                    "低：几乎总应是 static；仅反射/动态场景例外")
    );


    public static final Map<String, Rule> BY_CODE = RULES.stream()
            .collect(Collectors.toUnmodifiableMap(Rule::code, x -> x));
    public static final Map<String, Rule> BY_NAME = RULES.stream()
            .collect(Collectors.toUnmodifiableMap(Rule::name, x -> x));

    private static Rule r(String code, String name, String severity, List<String> langs,
                          String zh, String en, String fix, String fp) {
        return new Rule(code, name, severity, langs, zh, en, fix, fp);
    }

    public static Optional<Rule> parse(String token) {
        String t = token.trim();
        Rule byCode = BY_CODE.get(t);
        if (byCode != null) return Optional.of(byCode);
        return Optional.ofNullable(BY_NAME.get(t.toLowerCase(Locale.ROOT)));
    }
}
