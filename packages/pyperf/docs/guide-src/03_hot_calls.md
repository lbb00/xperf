## 3. Parse and deep copy

`json.loads` / `json.dumps` and `deepcopy` inside a loop repeat work that belongs outside it when the value does not change. A changing payload cannot be hoisted. These lints are **hint** and have a microbench. `re.compile` was removed: CPython caches it, and the measured difference stayed under 3×. `datetime.strptime` / `strftime` was removed: a fixed string is faster only when the call is skipped, and a changing string has nothing to hoist.

`open` of one path inside a loop repeats the open. One measured shape, a one-byte file, was about 409×. A path that changes every iteration cannot be hoisted. `time.perf_counter_ns` was about 2.9× and `getattr` about 1.4×; those were checked and not given a rule.

Companion lint: **pp-json-in-loop**, **pp-deepcopy-in-loop**, **pp-open-in-loop**.
