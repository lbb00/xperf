struct Small {
    int a;
    int b;
    int c;
    int d;
};

struct Mid {
    int a;
    int b;
    int c;
    int d;
    int e;
    int f;
    int g;
    int h;
    unsigned char pad[400];
};

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

unsigned good_small(struct Small s) {
    return (unsigned)s.a + (unsigned)s.d;
}

unsigned good_mid(struct Mid s) {
    return (unsigned)s.a + s.pad[0];
}

unsigned good(const struct Blob *s) {
    return (unsigned)s->a + (unsigned)s->h + s->pad[0] + s->pad[479];
}
