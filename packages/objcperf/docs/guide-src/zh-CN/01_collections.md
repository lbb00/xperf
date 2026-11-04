## 1. 集合

`[[NSMutableArray alloc] init]` 再多次 `addObject:` 可能反复扩容。已知 `n` 时优先 `arrayWithCapacity:`。没有 lint 覆盖：抖动受控复测未显示可靠加速后，容量规则已移除。
