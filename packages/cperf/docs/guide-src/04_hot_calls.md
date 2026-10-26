## 4. Hot calls

A hot loop should not format a new string, open a file, sample the clock, or compile a regular expression on every pass. Format into a buffer you already have, open the stream once, read the clock outside the steady state, and compile a pattern once. These lints are **hint**. The 2026-10-22 corpus verdict does not cover them.

- **cp-sprintf-in-loop** — `sprintf` or `snprintf` in a loop body. JSONL is present. The rule stays hint and is not corpus-triaged.
- **cp-fopen-in-loop** — `fopen` in a loop body. JSONL is present. The rule stays hint and is not corpus-triaged.
- **cp-gettime-in-loop** — `gettimeofday` or `clock_gettime` in a loop body. A bare `time` call is not matched; that name is too broad. JSONL is present. The rule stays hint and is not corpus-triaged.
- **cp-regex-in-loop** — `regcomp` in a loop body. `regexec` is not matched. A microbench was about 9.7× versus compiling once. The rule stays **hint** and is not corpus-triaged.

A fixture hit is not a measured speedup. See [evidence-policy.md](evidence-policy.md).
