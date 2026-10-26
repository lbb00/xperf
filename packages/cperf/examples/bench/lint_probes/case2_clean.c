#include <stdio.h>
void clean(int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s += i;
    printf("%d\n", s);
}
