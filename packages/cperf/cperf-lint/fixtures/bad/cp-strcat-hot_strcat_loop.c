#include <string.h>
void bad(char *dst, char **parts, int n) {
    dst[0] = '\0';
    for (int i = 0; i < n; i++) {
        strcat(dst, parts[i]);
    }
}
