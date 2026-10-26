/* Arena bump allocator: many short-lived objects, one free_all.
 * cc -std=c17 -O2 -o m01 m01_arena.c && ./m01
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint8_t *base;
    size_t len;
    size_t cap;
} Arena;

static void arena_init(Arena *a, size_t cap) {
    a->base = (uint8_t *)malloc(cap);
    a->len = 0;
    a->cap = a->base ? cap : 0;
}

static void *arena_alloc(Arena *a, size_t n, size_t align) {
    size_t p = (a->len + align - 1) & ~(align - 1);
    if (p + n > a->cap) return NULL;
    a->len = p + n;
    return a->base + p;
}

static void arena_reset(Arena *a) { a->len = 0; }

static void arena_free(Arena *a) {
    free(a->base);
    a->base = NULL;
    a->len = a->cap = 0;
}

int main(void) {
    Arena a;
    arena_init(&a, 1 << 20);
    if (!a.base) return 1;
    for (int i = 0; i < 1000; i++) {
        int *x = (int *)arena_alloc(&a, sizeof(int), _Alignof(int));
        if (!x) return 2;
        *x = i;
    }
    arena_reset(&a);
    arena_free(&a);
    puts("ok");
    return 0;
}
