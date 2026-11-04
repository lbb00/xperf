## 2. Shape 与 delete

`delete` 与混杂的属性 shape 会走多态路径；更稳妥的是稳定对象布局（与 V8 hidden class 同一思路——请在 ArkTS 上**重测**）。

对 `delete` 与 `Map.delete` 的 Node 代理约 1×，因此没有对应 lint。在 ArkTS VM 上重测后再考虑新增。
