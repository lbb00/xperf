void good(int n) {
    char *p = alloca(64);
    char *q = __builtin_alloca(32);
    for (int i = 0; i < n; i++) {
        char buf[n];
        buf[0] = p[0];
        p[0] = (char)i;
        q[0] = buf[0];
    }
}
