#include <stdlib.h>
void clean(int n) {
    void *buf = malloc((size_t)n * 4u);
    (void)buf;
    free(buf);
}
