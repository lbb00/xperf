# jvmperf corpus targets

## Pins

Large trees are **not** vendored in this package and do not ship with the repo.
Clone them to any local directory and pass that path to the linter. No commit pins are recorded for these trees; note the revision you scanned next to your results.

```sh
export JAVA_HOME=/opt/java/jdk-21.0.12.1+1   # or any JDK 21+
cd packages/jvmperf/jvmperf-lint && ./gradlew jar
LINT=$PWD/bin/jvmperf-lint
$LINT --no-fail -f json -j 4 <path-to-clone>
```

Checker is **Java** (`jvmperf-lint`). No Python in this kit.

Default severities follow `Rule.java`: **error** jp-string-concat-in-loop, jp-boxed-stream, jp-enum-key-hash-collection, jp-data-copy-in-loop, jp-baos-tobytearray-copy, jp-hot-payload-copy, jp-client-factory-recreate, jp-string-intern-in-loop (G4 JSONL); **hint** jp-value-class-boxing, jp-android-sparse-array, jp-finalize, jp-hot-system-call, jp-bitmap-decode-no-reuse, jp-hot-post-lambda, jp-ui-text-append, jp-non-static-field-updater; every other rule is **off** (select with `--enable`).

### Inventory

```text
<corpus-dir>/
  okhttp/ retrofit/ kotlinx-coroutines/ guava/ vertx/ fastjson2/
  jetty/          # sparse jetty-core
  netty/          # sparse buffer + common
```

Do not commit corpus sources into `packages/jvmperf`.

## Cloned + G3 (2026-10-22, Asia/Shanghai) — r6

| Tree | Scope | after4 → r5 → **r6** |
|------|-------|---------------------:|
| **okhttp** | whole | 48 → 9 → **6** (jp-data-copy-in-loop) |
| **retrofit** | whole | 6 → 0 → **0** |
| **kotlinx.coroutines** | whole | 4 → 0 → **0** |
| **guava** | `guava/src` only | 30 → 3 → **1** |
| **vert.x** | whole | 60 → 10 → **1** |
| **fastjson2** | whole | 49 → 12 → **8** |
| **Jetty** | sparse `jetty-core` | 267 → 55 → **6** |
| **Netty** | sparse `buffer` + `common` | 24 → 8 → **4** |
| **Total (8 trees)** | | **488 → 97 → 26** |

**G3 triage:** run locally; triage notes are not shipped.

**corpus-ready: yes** — r6 n=26 full: TP 50%, FP+DOC+SKIP 0%; honest TP on jp-data-copy-in-loop/jp-hot-payload-copy/jp-finalize; every default **error** has G4 (`evidence/*.md`+`jsonl`).

### Reverse-opt

- Path: `samples?/examples?/recipes?/demos?/snippets?` → `source_group=test` (plus prior benchmark/KMP test skips)
- Demote almost-all OK-idiom / no-G4 hot heuristics to **off** (for example jp-unpresized-collection, jp-hot-heavy-alloc, jp-hot-format-log)
- Keep measured usefulness backbone as **error** (for example jp-string-concat-in-loop, jp-data-copy-in-loop, jp-hot-payload-copy)
