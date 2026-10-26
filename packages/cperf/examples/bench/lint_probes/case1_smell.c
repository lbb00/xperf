#include <stdlib.h>
void smell(int n) {
    for (int i = 0; i < n; i++) {
        void *p = malloc(4);
        free(p);
    }
}
