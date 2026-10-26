## 2. Shapes and delete

`delete` and mixed property shapes make polymorphic paths; prefer stable object layouts (same idea as V8 hidden classes — **re-bench** on ArkTS).

A Node proxy of `delete` versus `Map.delete` was about 1×, so there is no lint for it. Re-bench on an ArkTS VM before adding one.

