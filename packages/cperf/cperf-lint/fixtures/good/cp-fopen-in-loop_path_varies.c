#include <stdio.h>
void good(char **paths, int n) {
    for (int i = 0; i < n; i++) {
        FILE *fp = fopen(paths[i], "rb");
        if (!fp) continue;
        fclose(fp);
    }
}
