#include <stdlib.h>
void *grow_cap(void *p, size_t *cap, size_t need) {
    if (need <= *cap) return p;
    size_t ncap = *cap ? *cap * 2 : 8;
    while (ncap < need) ncap *= 2;
    void *q = realloc(p, ncap);
    if (q) *cap = ncap;
    return q;
}
