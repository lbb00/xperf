# rs-alloc-hot — 在循环中分配/克隆（Vec::new / .clone / to_string / to_owned）

## 主张

在一个高频循环中（构建缓冲区、丢弃、重复）使用新的 `Vec::new()` 比使用 `clear`/`with_capacity` 重用在这台机器上 rustc `-C opt-level=3` 下只慢约 **~2.7×**。定型的固定 `seed.clone()` 到一个 `Vec` 中，在有无 `Vec::with_capacity` 的情况下大约是 **~1.1×**（克隆成本占主导）。每步增长 `String::clone` 与 `clear`+`push_str` 重用相比，大约慢 **~2.2×**。`i.to_string()` 与重用的 `clear`+`write!` 相比，大约慢 **~1.7×**。小 N 的重复短期 `Vec::new` 可能显示约 **~9×**，但这仍远低于 lu-string-concat-hot / rs-format-rebind-hot 类型的性能提升，并且探测器也会识别 G3 OK-idiom Id/`to_owned` 构建器。**不要**将整个 rs-alloc-hot 升级为 `error`；**不要**在没有探测器排除 OK-idiom 的情况下发明子规则升级它。

## 如何测量

- 利用:`包/壳/样本/箱/证据 rs001.rs'
- 构件:`rustc-C opt-level=3 证据 rs001.rs-o out/证据 rs001'
- 计时器:`std:时间:即时 ' 墙钟;温暖=3;中位数为9;`std:hint::black box '
- A对:外=50000×内=64推
- ** 之前:** `vic: new()' 每一个外延
- ** 后面:** 1个`系数:具有 容量(内)`+`清晰'每个外部
- 配对B(配对 'rustperf-lint/fixtures/bad/rs-alloc-hot clone loop.rs ' 容量意图):N=200000,种子=64
- ** 之前:**`威奇:新'+`种子.clone()'推
- ** 之后:** `系数:具有 容量(N)' + 相同的克隆
- C对(生长型克隆人):N=8000
- ** 在此之前:** `ac ' 增加一个字符;`ac.clone()' 每一步骤
- ** 之后:** 相同的生长;`buf.clear();buf.push str(和acc)'再利用
- D对数:N=200000
- ** 在**`i.to string()'之前
- ** 之后:** 重新使用`String' +`clear' + `write!' 后:** 重复使用`String' +`clear' +`write! '
- E对(小N界限):外部=100×内部=16×20000 计时层外代表
- 原始线路: [rs-alloc-hot.jsonl] (rs-alloc-hot.jsonl)

## 运行时（本证据文件）

| Field | Value |
|-------|--------|
| 时间 | 2026-10-22 亚洲/上海（机器时钟；JSONL `ts` 为 UTC） |
| rustc | **1.99.1** |
| 选项 | **优化级别=3** (`-C opt-level=3`) |
| `vec_new_each_iter` 之前的中位数 | 4.955 毫秒 |
| (`vec_clear_reuse`) 之后的中位数 | 1.810 毫秒 |
| **ratio Vec::new each** | **~6.11×** |
| 中值之前 (`clone_vec_new`) | 5.979 毫秒 |
| (`clone_with_capacity`) 后的中位数 | 5.398 毫秒 |
| **比率夹具克隆** | **~1.08×** |
| (`grow_clone_each`) 之前的中位数 | 0.550 毫秒 |
| 调用 (`grow_clear_push_str`) 后的中位数 | 0.247 毫秒 |
| **克隆比例增长** | **~1.81×** |
| 中位数之前 (`to_string_each_iter`) | 4.342 毫秒 |
| (`to_string_clear_write`) 之后的中位数 | 2.488 毫秒 |
| **ratio to_string** | **~1.56×** |
| 调整前中位数 (`small_n_vec_new_each`) | 178.412 毫秒 |
| (`small_n_vec_clear_reuse`) 之后的中位数 | 19.802 毫秒 |
| **ratio small N** | **~11.95×** |

说明：在新的 `Vec::new` 上，重用/`clear` 略微胜出；测试夹具 `clone` 约为 1×；这里没有任何内容能匹配 rs-format-rebind-hot 的 ~99×。绝对毫秒数和比率取决于机器/优化。rustc 或机器更改后，请重新运行测试。

## 与 lint 的对应

`rustperf-lint` **rs-alloc-hot** 会标记真实的 `for`/`while`/`loop` 循环窗口内的 `Vec::new` / `.to_string()` / `.to_owned()` /（逆向优化）类似缓冲的 `.clone()`。默认严重性为 **`off`**（使用 `--severity rs-alloc-hot=hint` 来查看）：JSONL 存在，但比率适中（约 1–9×），G3 clap/serde 残留大多为 OK-惯用 Id/`to_owned` 构建器。**不要**大规模升级。未来的精细拆分（例如仅循环体内的 `Vec::new`，不包括一次性构建器）仍然需要在设为 `error` 前单独设定检测器和证据。

## 限制

- 微基准测试；不是应用程序配置文件。
- 配对 B 仅容量后不会移除克隆分配 — 预期约为 1×。
- 配对 C 重用仍会复制字节；主要优势是避免每步创建新的 `String` 分配。
- 配对 E 为定时器分辨率乘以小构建器；`ops` 是每批单元（100）的外部构建次数，而不是总的 push 次数。
- 历史注：早期 G3 使用了大量 OK-惯用法；套件后来通过 rs-vec-no-capacity/rs-collect-vec-hot 翻转为 **语料库准备好**（参见 docs/corpus.md）。rs-println-hot 自那时起已被测量（提示）。
