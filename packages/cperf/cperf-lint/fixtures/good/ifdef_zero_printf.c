#include <stdio.h>
void table_build_dead(void) {
    int i;
#if 0
    for (i = 0; i < 10; i++) {
        printf("0x%06x, ", i); /* dead codegen helper — must not fire */
    }
#endif
    (void)i;
}
