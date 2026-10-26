#include <stdlib.h>
void *once(int n) {
    void *p = malloc((size_t)n * 64);
    return p;
}
void use(void *p, int n) {
    for (int i = 0; i < n; i++) {
        ((char *)p)[i] = 0;
    }
}
