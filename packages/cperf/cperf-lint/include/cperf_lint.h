/* cperf-lint — heuristic C/C++ performance checker (C11). */
#ifndef CPERF_LINT_H
#define CPERF_LINT_H

#include <stddef.h>

typedef struct {
    char *rule;
    char *path;
    int line;
    char *message;
} Finding;

typedef struct {
    Finding *items;
    size_t len;
    size_t cap;
} FindingList;

void finding_list_init(FindingList *fl);
void finding_list_free(FindingList *fl);
int finding_list_push(FindingList *fl, const char *rule, const char *path,
                      int line, const char *message);

/* Scan one file; append findings. Returns 0 on success, -1 on I/O error. */
int scan_file(const char *path, FindingList *out);

/* Scan file or directory tree. Returns 0 on success, -1 if any I/O error. */
int scan_path(const char *path, FindingList *out);

int should_skip_path(const char *path);

#endif

/* Internal helpers (also used by pathwalk). */
int cperf_ci_strstr(const char *hay, const char *needle);
int cperf_is_ident_start(char c);
int cperf_is_ident(char c);
const char *cperf_find_word(const char *s, const char *word);
const char *cperf_find_word_ci(const char *s, const char *word);
