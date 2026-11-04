# kotlinperf证据政策

## 门槛

仅当`evidence/<RULE>.md`+`.jsonl` **和* *为显式策略决策时，规则才可被视为**`error`。单独测量JSONL不会**自动升级。批次B (2026-10-22)保持包装默认值。

## 当前映射

截至2026-10-22(B批次G4)。

|规则|严重性(默认)|证据|气味|
|------|--------------------|----------|-------|
| kt-list-add-hot | off | * * yes * * ~ 2.1×| ArrayList空vs cap |
| kt-string-plus-hot | off | * * yes * * ~ 1170×| string+= |
lpuzmt1rpesc9ruj7cxv
ooo5nkvl4oeg185ia2dh
