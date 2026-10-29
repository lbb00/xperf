#include <stdio.h>
void good(const char *path, int n, char *buf) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return;
    for (int i = 0; i < n; i++) {
        int c = fgetc(fp);
        if (c < 0) break;
        buf[i] = (char)c;
    }
    fclose(fp);
}
