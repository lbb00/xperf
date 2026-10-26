## 1. Optionals and hot paths

Force-unwrap (`!`) in a tight loop crashes on nil and skips safer control flow. Prefer `guard let` / `if let` once per iteration or hoist.

Force-unwrap and `if let` took the same time on a non-nil array, so there is no lint for it.
