#include <stdio.h>
void bad(int n) {
    for (int i = 0; i < n; i++) {
        FILE *fp = fopen("one.txt", "rb");
        if (!fp) continue;
        fclose(fp);
    }
}
