## Lint map

| ID | Smell | Default |
|----|-------|---------|
| CX001 | removed (jitter) | — |
| cx-regex-ctor-hot | `std::regex` constructed in loop | **hint** (JSONL present; not corpus-triaged) |
| cx-endl-hot | `endl` flush in loop | **hint** (JSONL present; not corpus-triaged) |
| cx-clock-hot | clock sample in a loop | **hint** (JSONL; about 147× vs one sample; not corpus-triaged) |
| cx-ifstream-hot | file stream opened in a loop | **hint** (JSONL; about 2025× on one one-byte file; not corpus-triaged) |
| cx-const-by-value | `const` string or vector copied by value | **hint** (JSONL; about 15–21× when the copy allocates; not corpus-triaged) |
| cx-vector-bool | packed bool element container | **hint** (JSONL; walk about 12× vs a byte vector; not corpus-triaged) |
| CX003 | removed (jitter) | — |
| CX004 | removed (jitter) | — |

Escalate only with `evidence/cx-*.jsonl` — see [evidence-policy.md](evidence-policy.md). The retired CX004 showed that `-O2` can erase the effect; measure at `-O0` / sanitizers if claiming speed.

## References

- [XPerf playbook](../../../docs/playbook.md)
