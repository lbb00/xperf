#include <stdlib.h>
/* Brace-less for must not poison the next function as "in loop". */
static void dump_range(int *p, int n) {
    for (int i = 0; i < n; i++)
        (void)p[i];
}
static void *cr_default_realloc(void *opaque, void *ptr, size_t size) {
    (void)opaque;
    return realloc(ptr, size);
}
