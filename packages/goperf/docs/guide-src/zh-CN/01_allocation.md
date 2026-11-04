## 1. 分配

画像显示分配压力时，紧密循环里优先复用缓冲区（`sync.Pool`、预分配 slice），而不是 `make`/`new`。逃逸分析可能把小值留在栈上——**没有 bench 就不要改**。

配套 lint：**gp-make-hot**（G3 后 off）、**gp-append-nil-slice**（空 slice + 有大小提示循环里的 append）。
