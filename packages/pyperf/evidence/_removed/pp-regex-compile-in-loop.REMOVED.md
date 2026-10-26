# pp-regex-compile-in-loop — removed 2026-10-23 (Asia/Shanghai)

Status: **removed**. CPython caches `re.compile`. The checked-in microbench was **1.22×** (CPython 3.14, 5000 ops). A later rerun on a short haystack was **2.05×** and on a longer haystack **2.62×** (CPython 3.9). The search dominates the compile.

- Slug **never reused**.
- Historical JSONL and markdown stay beside this note. Fixtures moved under `_removed/fixtures/`.
- Gate: a fair microbench that stays near 1× cannot remain an active lint.
