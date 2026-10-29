## 3. Compile, encode, and reflect

`regexp.Compile` / `MustCompile` and `json.Marshal` / `Unmarshal` inside a loop repeat work that can be done once when the pattern or payload does not change. `FieldByName`, `MethodByName`, and `reflect.New` inside a loop are the reflect lint. `TypeOf` on a concrete value was about 1.3× and is not matched. `time.Parse` was removed: a fixed timestamp is faster only when the parse is skipped, and a changing timestamp has nothing to hoist. These lints are **hint**.

`os.Open` of one path was about 2300× versus opening once. `time.Now` was about 104× versus one sample. That clock rule is not the removed `time.Parse` rule. A changing path cannot be hoisted, and a loop that needs a fresh timestamp has nothing to hoist.

Companion lint: **gp-regexp-compile-hot**, **gp-json-marshal-hot**, **gp-reflect-hot**, **gp-os-open-hot**, **gp-time-now-hot**.
