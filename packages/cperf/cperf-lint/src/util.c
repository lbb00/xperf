#include "cperf_lint.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void finding_list_init(FindingList *fl) {
    fl->items = NULL;
    fl->len = 0;
    fl->cap = 0;
}

void finding_list_free(FindingList *fl) {
    if (!fl) return;
    for (size_t i = 0; i < fl->len; i++) {
        free(fl->items[i].rule);
        free(fl->items[i].path);
        free(fl->items[i].message);
    }
    free(fl->items);
    fl->items = NULL;
    fl->len = fl->cap = 0;
}

int finding_list_push(FindingList *fl, const char *rule, const char *path,
                      int line, const char *message) {
    if (fl->len + 1 > fl->cap) {
        size_t ncap = fl->cap ? fl->cap * 2 : 64;
        Finding *n = realloc(fl->items, ncap * sizeof(Finding));
        if (!n) return -1;
        fl->items = n;
        fl->cap = ncap;
    }
    Finding *f = &fl->items[fl->len];
    f->rule = strdup(rule);
    f->path = strdup(path);
    f->message = strdup(message);
    f->line = line;
    if (!f->rule || !f->path || !f->message) {
        free(f->rule);
        free(f->path);
        free(f->message);
        return -1;
    }
    fl->len++;
    return 0;
}

/* --- shared string helpers used by scan / pathwalk --- */

int cperf_ci_strstr(const char *hay, const char *needle) {
    if (!hay || !needle || !*needle) return 0;
    size_t nlen = strlen(needle);
    for (const char *p = hay; *p; p++) {
        size_t i = 0;
        while (i < nlen && p[i] &&
               tolower((unsigned char)p[i]) == tolower((unsigned char)needle[i]))
            i++;
        if (i == nlen) return 1;
    }
    return 0;
}

int cperf_is_ident_start(char c) {
    return isalpha((unsigned char)c) || c == '_';
}

int cperf_is_ident(char c) {
    return isalnum((unsigned char)c) || c == '_';
}

/* Word-boundary search for needle as a whole identifier/keyword. */
const char *cperf_find_word(const char *s, const char *word) {
    size_t wlen = strlen(word);
    for (const char *p = s; *p; p++) {
        if (strncmp(p, word, wlen) != 0) continue;
        if (p > s && cperf_is_ident(p[-1])) continue;
        if (cperf_is_ident(p[wlen])) continue;
        return p;
    }
    return NULL;
}

const char *cperf_find_word_ci(const char *s, const char *word) {
    size_t wlen = strlen(word);
    for (const char *p = s; *p; p++) {
        size_t i = 0;
        while (i < wlen && p[i] &&
               tolower((unsigned char)p[i]) == tolower((unsigned char)word[i]))
            i++;
        if (i != wlen) continue;
        if (p > s && cperf_is_ident(p[-1])) continue;
        if (cperf_is_ident(p[wlen])) continue;
        return p;
    }
    return NULL;
}
