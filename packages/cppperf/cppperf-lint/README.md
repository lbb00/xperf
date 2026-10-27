# cppperf-lint

C++17 heuristic checker (`cppperf-lint`).

| Slug | Default | Smell |
|------|---------|-------|
| `cx-regex-ctor-hot` | **hint** | `std::regex` constructed in a loop. JSONL present; not corpus-triaged |
| `cx-endl-hot` | **hint** | `endl` flush in a loop. JSONL present; not corpus-triaged |
| `cx-clock-hot` | **hint** | `clock_gettime`, `gettimeofday`, or chrono `now()` in a loop. JSONL about 147× versus one sample; stay hint |

Removed (jitter 2026-10-22, no slug — see `evidence/_removed/`): `CX001`, `CX003`, `CX004`.

Line/brace heuristics — not a full AST/SSA pass.
