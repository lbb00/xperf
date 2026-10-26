# jvmperf `lib/` — optional bench jars (not in git)

These jars are used by JMH / JOL / Kotlin alloc examples. They are **gitignored**
(`*.jar` at repo root). Do not commit them.

Fetch with:

```sh
bash packages/jvmperf/scripts/fetch-lib.sh
# or from this package:
bash scripts/fetch-lib.sh
```

Set `JVMPERF_LIB_DIR` to override the directory (default: this `lib/`).

| Artifact | Version | SPDX (upstream) | Maven Central path (group/artifact) |
|----------|---------|-----------------|-------------------------------------|
| jmh-core | 1.37 | GPL-2.0-with-classpath-exception (OpenJDK JMH) | `org.openjdk.jmh:jmh-core` |
| jmh-generator-annprocess | 1.37 | same | `org.openjdk.jmh:jmh-generator-annprocess` |
| jopt-simple | 5.0.4 | MIT | `net.sf.jopt-simple:jopt-simple` |
| commons-math3 | 3.6.1 | Apache-2.0 | `org.apache.commons:commons-math3` |
| jol-core | 0.17 | GPL-2.0-with-classpath-exception | `org.openjdk.jol:jol-core` |
| fastutil-core | 8.5.19 | Apache-2.0 | `it.unimi.dsi:fastutil-core` |
| eclipse-collections | 13.0.0 | EPL-1.0 / EDL-1.0 | `org.eclipse.collections:eclipse-collections` |
| eclipse-collections-api | 13.0.0 | EPL-1.0 / EDL-1.0 | `org.eclipse.collections:eclipse-collections-api` |
| kotlinx-coroutines-core-jvm | 1.11.0 | Apache-2.0 | `org.jetbrains.kotlinx:kotlinx-coroutines-core-jvm` |
| collection-jvm (androidx) | 1.7.0 | Apache-2.0 | `androidx.collection:collection-jvm` |
| annotation-jvm | 1.9.1 | Apache-2.0 | `androidx.annotation:annotation-jvm` |
| jspecify | 1.0.0 | Apache-2.0 | `org.jspecify:jspecify` |

Confirm current license text on each project’s upstream page before redistribution
outside this fetch-for-local-bench workflow.
