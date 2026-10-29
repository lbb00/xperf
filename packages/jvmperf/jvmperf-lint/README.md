# jvmperf-lint

`jvmperf-lint` checks Java and Kotlin source for performance and memory patterns. It is a **Java 21+** CLI that uses tree-sitter parsers and does not compile code or resolve types, so findings are review prompts rather than compiler diagnostics.

## Build and run

Requires JDK 21 or newer.

```sh
./gradlew jar
bin/jvmperf-lint path/to/source
```

For development:

```sh
./gradlew test
./gradlew run --args='--list-rules'
```

## Common options

```text
jvmperf-lint [options] <file-or-directory>...

-f, --format text|json       Output format
--enable RULES               Run only the listed rule IDs or names (also reaches default-off rules)
--disable RULES              Skip the listed rule IDs or names
--strict-parse               Return an error when syntax errors are found
--hot-fn REGEX               Mark matching function names as hot
--hot-callbacks NAMES        Add event callback names
--no-hot-propagation         Disable local hot-context propagation
-j, --jobs N                 Worker thread count
--list-rules                 List rules, fixes, and false-positive risks
--no-fail                    Do not fail on findings or per-file analysis/I/O errors
--include-tests              Also scan source_group=test (skipped by default)
--strict-stdio-in-loop       Flag System.out/err and Kotlin print/println in loops
--version                    Print the version
-h, --help                   Print usage
```

Directories are scanned recursively for `.java`, `.kt`, and `.kts` files. Build, IDE, and version-control directories are skipped. **Test sources** (`source_group=test`, e.g. `src/test`, `*Test.java`) are skipped by default — pass `--include-tests` to lint them (same default-off posture as zperf for test/build paths). Explicit file paths are always linted. Without `--enable`, rules whose default severity is `off` are skipped.

Exit code `0` means no findings (or `--no-fail`), `1` means findings, and `2` means an argument, I/O, or strict parse error. With `--no-fail`, per-file analysis exceptions are recorded in JSON `analysis_errors` and do not force exit `2`.

`System.out` / `System.err` / Kotlin `print`/`println` inside loops are **not** flagged unless `--strict-stdio-in-loop` is set. Framework loggers (and Android `Log`) still fire jp-log-hot, with demotions for `main`/`dump*`/`print*`/`debug*` methods, `samples/`/`examples/` paths, level guards (`isDebugEnabled` / `isLoggable`), and simple sampling branches.

Suppress a finding on the current or following line with `// jvmperf-lint: ignore jp-boxed-primitive-collection`. Use `// jvmperf-lint: ignore-file jp-regex-hot` to suppress a rule for the entire file. Kotlin uses the same comment syntax.

Use `--list-rules` for the complete rule catalog. The [performance guide](../docs/en/performance-guide.md) explains the patterns and tradeoffs.

## Removed (2026-10-22)

`jp-legacy-synchronized-type`, `jp-many-boolean-fields` — measured no win; see `../evidence/_removed/`.
