## 15. jvmperf-lint: find patterns automatically

`jvmperf-lint/` is the guide's static checker. It is written in Java and uses tree-sitter via the JVM bindings (`io.github.bonede:tree-sitter` with `tree-sitter-java` and `tree-sitter-kotlin`) to inspect `.java`, `.kt`, and `.kts` files. It reads syntax only and **does not resolve types**. This keeps it fast and configuration-free, but it can report false positives or miss issues; each rule documents its risk. See [`jvmperf-lint/README.md`](../../jvmperf-lint/README.md) for installation and usage.

```sh
cd jvmperf-lint
./gradlew jar
bin/jvmperf-lint path/to/src
bin/jvmperf-lint -f json --disable jp-finalize,jp-ui-text-append src
```

### 15.1 Rule catalog

Default severity is `error`, `hint`, or `off`, as printed by `bin/jvmperf-lint --list-rules`. Rules marked `off` do not run unless you select them with `--enable`.

| ID | Name | Default severity | Languages | Detection | Chapter |
|---|---|---|---|---|---|
| jp-boxed-primitive-collection | `boxed-primitive-collection` | off | Java/Kotlin | `List<Integer>`, `Map<Long,…>`, Kotlin `List<Int>`, `Array<Int>`, or `HashMap<Int,…>` | 3, 7.1 |
| jp-string-concat-hot | `string-concat-in-loop` | error | Java/Kotlin | `s += x` or `s = s + x` in a loop | 6.2 |
| jp-regex-hot | `regex-in-loop` | off | Java/Kotlin | `Pattern.compile`, `Regex(...)`, `replaceAll`, or non-fast-path `split` in a loop | 6.3 |
| jp-format-hot | `format-in-loop` | off | Java/Kotlin | `String.format`, `.formatted`, or Kotlin `.format` in a loop | 6.4 |
| jp-unpresized-collection | `unpresized-collection` | off | Java/Kotlin | A collection or `StringBuilder` is filled in a loop without initial capacity | 5.2 |
| jp-boxed-stream | `boxed-stream` | error | Java | `reduce(0, Integer::sum)` or `Collectors.summingInt` on `Stream<Integer>` | 3.1 |
| jp-exception-control-flow | `exception-control-flow` | off | Java/Kotlin | A loop catches parse exceptions to make a decision | 9.5 |
| jp-legacy-synchronized-type | — | **removed** | — | measured ~1.08×; see `evidence/_removed/` | — |
| jp-many-boolean-fields | — | **removed** | — | COH no win; see `evidence/_removed/` | — |
| jp-enum-key-hash-collection | `enum-key-hash-collection` | error | Java/Kotlin | `HashMap` keyed by an enum or `HashSet` of enum values | 5.3 |
| jp-collection-chain | `collection-chain` | off | Kotlin | A chain of 3+ `map`/`filter` operations, or 2 operations plus short-circuiting such as `first`, `take`, or `any` | 7.4 |
| jp-value-class-boxing | `value-class-boxing` | hint | Kotlin | A value class used as a nullable value, generic argument, or array element | 7.2 |
| jp-lambda-to-non-inline-hot | `lambda-to-non-inline-in-loop` | off | Kotlin | A loop passes a lambda to a non-inline higher-order function declared in the same file | 7.3 |
| jp-lazy-default-mode | `lazy-default-mode` | off | Kotlin | `by lazy { }` without an explicit mode | 7.5 |
| jp-data-copy-hot | `data-copy-in-loop` | error | Kotlin | `copy(...)` in a loop | 7.7 |
| jp-android-sparse-array | `android-sparse-array` | hint | Java/Kotlin | `HashMap<Integer/Long, …>` in Android source | 12.2 |
| jp-log-hot | `log-in-loop` | off | Java/Kotlin | `System.out.println`, `Log.d/v`, or an unguarded log call in a loop | 12.5 |
| jp-sleep-polling | `sleep-polling` | off | Java/Kotlin | A `while` loop that only sleeps and checks a condition | 10 |
| jp-finalize | `finalize` | hint | Java/Kotlin | Overrides `finalize()` | 9 |
| jp-expensive-alloc-hot | `expensive-alloc-in-loop` | off | Java/Kotlin | Constructs costly reusable objects such as `SimpleDateFormat`, `Random`, `ObjectMapper`, or `MessageDigest`, or a constant array of at least 256 bytes, inside a loop | 10.3 |
| jp-hot-heavy-alloc | `hot-heavy-alloc` | off | Java/Kotlin | Allocates `Paint`, `Path`, `Rect`, `Canvas`, `Matrix`, a bitmap, or an un-sized `ByteArrayOutputStream` in a hot context | 5.2, 12.5 |
| jp-hot-format-log | `hot-format-log` | off | Java/Kotlin | Formats strings or builds log messages in event callbacks; loop cases belong to jp-format-hot/jp-log-hot | 6.4, 12.5 |
| jp-hot-system-call | `hot-system-call` | hint | Java/Kotlin | Calls services, metrics, accessibility, package manager, settings, or Toast APIs in a hot context | 12.1 |
| jp-bitmap-decode-no-reuse | `bitmap-decode-no-reuse` | hint | Java/Kotlin | Calls `BitmapFactory.decode*` in a hot context without `inBitmap` reuse | 12.2, 10.3 |
| jp-hot-post-lambda | `hot-post-lambda` | hint | Java/Kotlin | Creates a new lambda for each event with `post { }` or `runOnUiThread { }` | 7.3 |
| jp-ui-text-append | `ui-text-append` | hint | Java/Kotlin | Assigns `new text + old text` to a `TextView`, copying and laying out the full string repeatedly | 6.2 |
| jp-baos-tobytearray-copy | `baos-tobytearray-copy` | error | Java/Kotlin | Copies the whole buffer with `ByteArrayOutputStream.toByteArray()` in a hot context | 8.3 |
| jp-hot-payload-copy | `hot-payload-copy` | error | Java/Kotlin | Allocates a payload-sized buffer and copies the whole payload in a hot context | 8.2, 8.3 |
| jp-client-factory-recreate | `client-factory-recreate` | error | Java/Kotlin | Recreates OkHttpClient / HttpClient-style factories instead of reusing | 10 |
| jp-string-intern-hot | `string-intern-in-loop` | error | Java/Kotlin | `String.intern()` inside a loop | 6 |
| jp-non-static-field-updater | `non-static-field-updater` | hint | Java | Non-static `Atomic*FieldUpdater` field | 9 |

The proposed rule `vt-unsafe-threadlocal-pool` is **guide-first** only (§10.2): high FP on ordinary `ThreadLocal` caches; not shipped (it is not in `Rule.RULES`). Paired samples live under `jvmperf-lint/fixtures/guide/` (not `bad/`/`good/`, so FixtureTest does not require a rule).

**Evidence-gated policy (keep / escalate):** package `evidence/<RULE>.{md,jsonl}` + [evidence-policy](../evidence-policy.md). Currently the default **error** rules are the eight that have both files: jp-string-concat-hot, jp-boxed-stream, jp-enum-key-hash-collection, jp-data-copy-hot, jp-baos-tobytearray-copy, jp-hot-payload-copy, jp-client-factory-recreate, jp-string-intern-hot. Rules with JSONL that stay below **error**: **hint** jp-value-class-boxing and jp-non-static-field-updater; **off** jp-boxed-primitive-collection, jp-regex-hot, jp-format-hot, jp-unpresized-collection, jp-exception-control-flow, jp-collection-chain, jp-lambda-to-non-inline-hot, jp-log-hot, and jp-expensive-alloc-hot. **Pending** (stub md only, mostly needing ART or a device): jp-lazy-default-mode, jp-android-sparse-array, jp-sleep-polling, jp-finalize, jp-hot-heavy-alloc, jp-hot-format-log, jp-hot-system-call, jp-bitmap-decode-no-reuse, jp-hot-post-lambda, jp-ui-text-append. See `scripts/run-static-vs-hotspot.sh`, [rule-regression](../../../../docs/rule-regression.md).

Suppress a finding with `// jvmperf-lint: ignore jp-boxed-primitive-collection,jp-string-concat-hot -- reason` on the current or previous line. Suppress rules for a file with `// jvmperf-lint: ignore-file jp-regex-hot`. Examples intentionally demonstrating a pattern use these directives.

**Hot-context inference (v0.3):** jp-hot-heavy-alloc–jp-hot-payload-copy infer why a source location may be hot instead of looking only for loops. Sources include non-periodic loops; event callbacks such as `onTouch`, `onDraw`, `onBindViewHolder`, `doFrame`, and `onImageAvailable`; lambdas registered as callbacks; names such as `onFrame` and `onJpeg`; user annotations (`// jvmperf-lint: hot`, `@HotPath`, or `--hot-fn`); and local call propagation (two levels in one file, one level across `Obj.f()` calls). Diagnostics show a reason chain such as `[hot: controlLoop:loop@404 → writeFrame → encode]`. Periodic loops, `accept()` loops, and catch blocks are excluded. jp-hot-format-log and jp-hot-post-lambda skip sampled branches such as `% NN`, `isLoggable`, `BuildConfig.DEBUG`, and `== ACTION_DOWN`.

The v0.3 hot-context rules were informed by Android screen-mirroring code reviews. They surfaced Binder calls and Toasts on every touch, per-frame `Bitmap`/`Canvas`/`ByteArrayOutputStream` allocations, text logs rebuilt by prepending new text, and full-frame copies.

### 15.2 Fixtures and tests

The `fixtures/bad/` and `fixtures/good/` directories contain Java and/or Kotlin fixtures for every **shipped** rule. Guide-only samples (`vt-unsafe-threadlocal-pool`) live under `fixtures/guide/`. They compile with javac 25 or kotlinc 2.4.21; Android fixtures compile against `android.jar`. Fixture and CLI tests run with `./gradlew test` (JUnit 5). They check rule coverage, clean fixtures, suppressions, JSON output, exit codes, hot-context call chains, and `--hot-fn`.

**Measured locally:** all 50 bad fixtures produced 76 findings in v0.3, and every file triggered its intended rule. The good fixtures produced no findings. A sample scan of 506 files in the JDK 25 `java.base/java/{util,text,io}` sources is recorded in `research/jdk-src-precision.txt`.

### 15.3 Comparison with other tools

`jvmperf-lint` complements established tools, especially for Kotlin allocation and boxing patterns and checks shared by Java and Kotlin. The following comparisons were checked against tool documentation on 2026-10-21.

| Tool | Approach | Relevant coverage | Requirements |
|---|---|---|---|
| [PMD](https://pmd.github.io/) 7.28.0 | Java source analysis | String concatenation, loop allocations, legacy synchronized collections, string-builder sizing, file streams, and array conversions | Source; auxiliary classpath for type resolution |
| [SpotBugs](https://spotbugs.github.io/) 4.10.5 | Bytecode analysis | String-buffer concatenation, regex compilation in loops, boxed primitives, map iteration, inner classes, and finalizers | Compiled `.class` files; Kotlin bytecode can produce more false positives |
| [find-sec-bugs](https://find-sec-bugs.github.io/bugs.htm) 1.14.0 | SpotBugs security plugin | Security checks; `REDOS` flags catastrophic regex backtracking | SpotBugs setup |
| [Error Prone](https://errorprone.info/bugpatterns) 2.50.0 | javac plugin | Obsolete JDK types, unnecessary boxing, wrapper constructors, finalizers, and string builders | Compile-time types; Java only |
| [detekt](https://detekt.dev/) 1.23.8 | Kotlin static analysis | Primitive arrays, sequence conversions, range loops, spread operators, and temporary objects | Some checks need type resolution and a classpath |
| [Android Lint](https://developer.android.com/studio/write/lint) | Android project analysis | Sparse collections, `valueOf`, draw allocations, logging, recycling, and ViewHolder patterns | Android project model, usually through AGP |
| [ktlint](https://github.com/pinterest/ktlint) 1.8.0 | Kotlin formatting and style | No performance rules | No compile required |
| [SonarQube / SonarLint](https://www.sonarsource.com/products/sonarlint/) | Multi-language analysis | Java string concatenation, legacy synchronized types, regex reuse, EnumMap/EnumSet; Kotlin focuses more on code smells and defects | Compiled output for full analysis |
| [Checkstyle](https://checkstyle.org/checks.html) 14.3.0 | Java style | No performance category; can forbid selected types or finalizers | No compile required |
| [IntelliJ inspections](https://www.jetbrains.com/help/inspectopedia/Java-Performance.html) | IDE analysis | About 40 Java performance checks plus Kotlin collection-chain conversions | IDE and type information |
| [OpenRewrite](https://docs.openrewrite.org/recipes) 2.45.0 | Automated refactoring | Rewrites string replacement, Stack usage, wrapper constructors, finalizers, and selected JDK migrations | Build plugin and type information |
| Runtime tools: [JOL](https://github.com/openjdk/jol), [JFR](https://docs.oracle.com/en/java/javase/25/jfapi/), [async-profiler](https://github.com/async-profiler/async-profiler), [JMH](https://github.com/openjdk/jmh) | Measurement | Measure object sizes, allocations, CPU hotspots, and time; use them to decide whether static findings matter | Run the application |

The main overlap is jp-string-concat-hot, the removed jp-legacy-synchronized-type, and jp-finalize/jp-expensive-alloc-hot with PMD; jp-regex-hot with SpotBugs and Sonar; jp-enum-key-hash-collection with Sonar and IntelliJ; and jp-collection-chain with detekt and IntelliJ. jvmperf-lint adds checks such as Kotlin `s +=` in loops, `value class` boxing, lambda allocation, `by lazy` defaults, coroutine/event-path allocations, and Android callbacks without requiring project compilation or type resolution.

Other tools detect useful patterns not covered here, including inefficient array conversions, incorrect map iteration, Kotlin spread operators, Android recycling and ViewHolder issues, and automated JDK migrations. A practical combination is Error Prone or PMD for Java, detekt for Kotlin, and Android Lint for Android projects. Treat every static warning as a hypothesis and use JFR, async-profiler, or JMH to confirm its impact.

### 15.4 Local comparison runs

PMD 7.28.0 was run on the bad Java fixtures with its full performance rules plus 10 related rules. It overlapped on jp-string-concat-hot, the since-removed jp-legacy-synchronized-type, jp-finalize, and jp-expensive-alloc-hot; its `AvoidInstantiatingObjectsInLoops` is broader and also reported harmless allocations in two good fixtures. Its performance rules did not include regex compilation inside loops. Full results are in `research/pmd-on-fixtures.txt` and the selected rule set is in `research/pmd-ruleset-compare.xml`.

detekt 1.23.8 was run on the bad Kotlin fixtures with `CouldBeSequence` enabled and style-noise rules disabled. It reported `ArrayPrimitive` twice for `Array<Long>`/`arrayOf(1L)` and `CouldBeSequence` once for a three-step chain; it did not report `List<Int>`, `HashMap<Int,Int>`, or the other 15 tested patterns. Its good fixtures had one unrelated `EmptyFunctionBlock` report. Probe files confirmed that `ForEachOnRange`, `SpreadOperator`, and `CouldBeSequence` work. `CouldBeSequence` required Kotlin stdlib 1.9.22 for type resolution; kotlinc 2.4.21's stdlib did not trigger it. Full results are in `research/detekt-on-fixtures.txt` and `research/detekt-probe-out.txt`.

Android Lint 8.2.0 was tested in standalone `--sources` mode. `LogConditional` (when enabled) and `UseValueOf` triggered, but `UseSparseArrays` did not report a `HashMap<Integer,String>`. Standalone mode may lack the AGP project model, so no conclusion is drawn about that rule. See `research/android-lint-probe.txt`.

SpotBugs, Error Prone, SonarQube, IntelliJ, and OpenRewrite were not run locally because they require compiled classes, compiler integration, a server, an IDE, or build plugins. Their mappings above come from their documentation. Check current versions before relying on the comparison.

### 15.5 Evidence gate and HotSpot correlation

Treat lint findings as review prompts until a rule has both `evidence/<RULE>.md` and `evidence/<RULE>.jsonl` (see [`docs/evidence-policy.md`](../evidence-policy.md)). Eight rules default to **error** (see the §15.1 note); several more have JSONL but stay **hint** or **off** when the correlate is modest, negative, or creation-only.

Cross-check: `scripts/run-static-vs-hotspot.sh` output under `research/benches/`. **Static lint ≠ HotSpot awareness** — do not claim C2 tier or failed escape analysis from source alone; do not use PrintCompilation line counts as the agree/disagree gate.

---

