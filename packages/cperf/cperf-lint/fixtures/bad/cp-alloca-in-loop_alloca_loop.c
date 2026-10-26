void bad(int n) {
    for (int i = 0; i < n; i++) {
        char *p = alloca(64);
        p[0] = (char)i;
        p[63] = 0;
    }
    int i = 0;
    while (i < n) {
        char *q = __builtin_alloca(64);
        q[0] = (char)i;
        q[63] = 0;
        i++;
    }
}
