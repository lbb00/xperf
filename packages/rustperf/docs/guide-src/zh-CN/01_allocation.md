## 1. 分配与 clone

画像显示有压力时，热循环里优先复用与容量，而不是 `Vec::new` / `.clone()` / `.to_string()`。

```rust
// prefer: pre-sized or reused buffer
// prefer: pre-sized or reused buffer
let mut v = Vec::with_capacity(n);
let mut v = Vec::with_capacity(n);
for i in 0..n { v.push(i); }
for i in 0..n { v.push(i); }
```

Lint: `rs-alloc-hot`（默认 off，G3 后；G4 有测量）
