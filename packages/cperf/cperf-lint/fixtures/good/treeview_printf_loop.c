#include <stdio.h>
/* sqlite3TreeView*-style pretty printers: cp-printf-in-loop suppressed */
static void sqlite3TreeViewLine(int n) {
    for (int i = 0; i < n; i++) {
        printf(" %d", i);
    }
    printf("\n");
}
