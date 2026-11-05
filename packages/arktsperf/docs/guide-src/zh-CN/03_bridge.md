## 3. Bridge / console 噪声

热路径上的 `console.log` 以及频繁的同步跨语言 / worker bridge 调用会拖帧。请门控调试 I/O。

Lint: `at-console-hot`（默认 off）
