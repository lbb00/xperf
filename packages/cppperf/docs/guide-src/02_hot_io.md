## 2. Hot I/O

`std::cout << ...` in a tight loop flushes and formats. Prefer buffered writers or `{fmt}` / `printf` outside the loop when profiles show pressure.

No lint rule covers this smell (CX003 was retired).

