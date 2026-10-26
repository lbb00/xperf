struct Blob {
    int a;
    int b;
    int c;
    int d;
    int e;
    int f;
    int g;
    int h;
    unsigned char pad[480];
};

unsigned bad(struct Blob s) {
    return (unsigned)s.a + (unsigned)s.h + s.pad[0] + s.pad[479];
}
