## 3. 编译、编码与反射

循环里的 `regexp.Compile` / `MustCompile` 与 `json.Marshal` / `Unmarshal` 会重复本可一次完成的工作（当模式或 payload 不变时）。循环里的 `FieldByName`、`MethodByName`、`reflect.New` 属于 reflect lint。对具体值的 `TypeOf` 约 1.3×，不匹配。`time.Parse` 已移除：固定时间戳仅在跳过解析时更快，变化的时间戳没有可外提的东西。这些 lint 是 hint。

对同一路径 `os.Open` 约 2300×（相对打开一次）。`time.Now` 约 104×（相对采一次样）。该时钟规则不是已移除的 `time.Parse` 规则。变化的路径不能外提；需要新鲜时间戳的循环也没有可外提的东西。

Lint: `gp-regexp-compile-hot`, `gp-json-marshal-hot`, `gp-reflect-hot`, `gp-os-open-hot`, `gp-time-now-hot`（默认 hint）
