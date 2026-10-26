#include <stdio.h>
void cursor_trace(int valid) {
    int i;
    for (i = 0; i < 3; i++) {
#ifdef SQLITE_DEBUG
        if (!valid) {
            printf("... cursor not valid - fall through\n");
        }
#endif
        (void)valid;
    }
}
