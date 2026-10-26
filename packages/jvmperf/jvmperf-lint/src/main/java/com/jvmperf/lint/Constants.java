package com.jvmperf.lint;

import java.util.Set;
import java.util.regex.Pattern;

public final class Constants {
    private Constants() {}

    public static final Set<String> BOXED_JAVA = Set.of(
            "Integer", "Long", "Short", "Byte", "Character", "Double", "Float", "Boolean");
    public static final Set<String> BOXED_KT = Set.of(
            "Int", "Long", "Short", "Byte", "Char", "Double", "Float", "Boolean");
    public static final Set<String> COLLECTIONS = Set.of(
            "List", "ArrayList", "LinkedList", "Collection", "Set", "HashSet", "LinkedHashSet", "TreeSet",
            "Map", "HashMap", "LinkedHashMap", "TreeMap", "Deque", "ArrayDeque", "Queue", "PriorityQueue",
            "MutableList", "MutableSet", "MutableMap", "MutableCollection", "Iterable", "Stack", "Vector");
    public static final Set<String> HASH_MAPS = Set.of("HashMap", "LinkedHashMap", "Hashtable");
    public static final Set<String> HASH_SETS = Set.of("HashSet", "LinkedHashSet");
    public static final Set<String> CF_EXCEPTIONS = Set.of(
            "NumberFormatException", "IndexOutOfBoundsException", "ArrayIndexOutOfBoundsException",
            "StringIndexOutOfBoundsException", "NoSuchElementException", "NullPointerException",
            "ClassCastException");
    public static final Set<String> EXPENSIVE_NEW = Set.of(
            "SimpleDateFormat", "DecimalFormat", "Random", "SecureRandom", "ObjectMapper", "Gson",
            "GsonBuilder", "XmlMapper", "DocumentBuilderFactory", "Scanner");
    public static final Set<String> KT_ARRAY_CTORS = Set.of(
            "ByteArray", "IntArray", "LongArray", "CharArray", "ShortArray", "FloatArray", "DoubleArray");
    public static final int BIG_BUFFER = 256;
    public static final String SPLIT_META = ".$|()[{^?*+\\";

    public static final Pattern IGNORE_RE = Pattern.compile("//\\s*jvmperf-lint:\\s*(ignore-file|ignore)\\b([^\\n]*)");
    public static final Pattern GUARD_RE = Pattern.compile(
            "isLoggable|is(Debug|Trace|Info|Warn|Error)Enabled|BuildConfig\\.DEBUG");
    public static final Pattern SAMPLE_BRANCH_RE = Pattern.compile(
            "%\\s*\\d+|\\b(every|each)\\s+\\d+|\\bsampl(e|ing)\\b|\\bdebugOnly\\b", Pattern.CASE_INSENSITIVE);
    public static final Pattern DIAGNOSTIC_METHOD_RE = Pattern.compile(
            "^(main|dump\\w*|print\\w*|debug\\w*|trace\\w*|toString)$", Pattern.CASE_INSENSITIVE);
    public static final Pattern SAMPLE_PATH_RE = Pattern.compile(
            "(?:^|/)(?:samples?|examples?|snippets?|recipes?|demos?)(?:/|$)", Pattern.CASE_INSENSITIVE);
    public static final java.util.Set<String> FUNCTIONAL_API_TYPES = java.util.Set.of(
            "Function", "BiFunction", "Predicate", "BiPredicate", "Consumer", "BiConsumer",
            "Supplier", "Comparator", "Callable", "Converter", "UnaryOperator", "BinaryOperator");
    public static final Pattern CODEGEN_PATH_RE = Pattern.compile(
            "(?:^|/)(?:codegen|generated?|gen)(?:/|$)|(?:^|/)Generate\\w+\\.(?:java|kt|kts)$|"
                    + "(?:Codegen|CodeGenerator)\\.(?:java|kt|kts)$|"
                    + "Converter\\.(?:java|kt)$",
            Pattern.CASE_INSENSITIVE);
    /** JSON/codec packages — boxed collections often required for null / API fidelity. */
    public static final Pattern CODEC_PACKAGE_PATH_RE = Pattern.compile(
            "(?:^|/)(?:com/alibaba/fastjson2|com/alibaba/fastjson|com/fasterxml/jackson|"
                    + "com/google/gson|kotlinx/serialization|org/json)(?:/|$)",
            Pattern.CASE_INSENSITIVE);
    /** Type-parameter-looking names at API boundaries (E, K, V, T, R1, …). */
    public static final Pattern TYPE_VAR_RE = Pattern.compile("^[A-Z][A-Z0-9]?$");
    /** Soft collections: unknown-size fill demoted; Hash* still flagged (rehash cost). */
    public static final Set<String> SOFT_UNPRESIZED = Set.of(
            "ArrayList", "ArrayDeque", "StringBuilder", "mutableListOf", "arrayListOf");
    public static final Set<String> CLIENT_FACTORY_TYPES = Set.of("OkHttpClient", "Retrofit");
    public static final Pattern SHORT_LIVED_METHOD_RE = Pattern.compile(
            "^(onCreate|onStart|onResume|get|invoke|call|execute|run|apply|handle|process|"
                    + "doGet|doPost|service|intercept)$",
            Pattern.CASE_INSENSITIVE);
    public static final Set<String> FIELD_UPDATER_TYPES = Set.of(
            "AtomicIntegerFieldUpdater", "AtomicLongFieldUpdater", "AtomicReferenceFieldUpdater");
    /** Methods that are cold / error / diagnostic — do not treat as hot via propagation. */
    public static final Pattern COLD_OR_ERROR_METHOD_RE = Pattern.compile(
            "^(error|fail|onError|onFailure|onFail|throw\\w*|assert\\w*|check\\w*|verify\\w*|"
                    + "toString|dump\\w*|print\\w*|debug\\w*|trace\\w*|describe\\w*|"
                    + "formatIllegal\\w*|illegalState\\w*|abort\\w*|handleError\\w*)$",
            Pattern.CASE_INSENSITIVE);
    public static final int TINY_LOOP_BOUND = 8;
    /** Path segment that marks test / host-test / KMP *Test source sets. */
    public static final Pattern TEST_SOURCE_PART = Pattern.compile(
            "(?:^|[-_])(?:unit|android|androidHost|androidUnit|jvm|common|native|ios|macos|js|wasm|host|integration|functional)?[_-]?tests?(?:$|[-_])"
                    + "|^(?:androidHost|androidUnit|common|jvm|native|ios|macos|js|wasm|host|unit|integration|functional|android)?[_-]?tests?$",
            Pattern.CASE_INSENSITIVE);
    /** JMH / benchmark trees — treated like tests (skipped unless --include-tests). */
    public static final Pattern BENCHMARK_PATH_RE = Pattern.compile(
            "(?:^|/)(?:benchmarks?|benchmark_[^/]+|jmh)(?:/|$)", Pattern.CASE_INSENSITIVE);
    /** Published test helpers / mock servers — high FP for layout rules. */
    public static final Pattern TESTING_SUPPORT_PATH_RE = Pattern.compile(
            "(?:^|/)(?:[^/]*testing-support[^/]*|[^/]*test-support[^/]*|testdata|test-data)(?:/|$)",
            Pattern.CASE_INSENSITIVE);
    /** Guava primitive specialized arrays — Collection<Integer> is the conversion API. */
    public static final Pattern IMMUTABLE_PRIMITIVE_ARRAY_RE = Pattern.compile(
            "^Immutable(Int|Long|Double|Boolean)Array$");
    public static final String[] SOURCE_GROUPS = {"production", "test", "smoke"};

    public static final Set<String> JAVA_LOOPS = Set.of(
            "for_statement", "enhanced_for_statement", "while_statement", "do_statement");
    public static final Set<String> JAVA_FUNCS = Set.of(
            "method_declaration", "constructor_declaration", "lambda_expression", "static_initializer");
    public static final Set<String> KT_LOOPS = Set.of("for_statement", "while_statement", "do_while_statement");
    public static final Set<String> KT_FUNCS = Set.of(
            "function_declaration", "anonymous_function", "getter", "setter",
            "anonymous_initializer", "secondary_constructor");
}
