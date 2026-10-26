## 1. Allocation and clone

Prefer reuse and capacity over `Vec::new` / `.clone()` / `.to_string()` inside hot loops when profiles show pressure.

```rust
// prefer: pre-sized or reused buffer
let mut v = Vec::with_capacity(n);
for i in 0..n { v.push(i); }
```

