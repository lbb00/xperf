#pragma once
#include <stddef.h>

typedef struct {
  const char *rule;
  char path[1024];
  int line;
  const char *message;
} Finding;

/* 1 = reverse-opt on (default); 0 = --raw-paths baseline */
extern int g_enable_reverse_opt;
/* 1 = --scope all (default); 0 = --scope loop */
extern int g_scope_all;

Finding *scan_file(const char *path, size_t *out_n);
Finding *scan_path(const char *root, size_t *out_n);
void free_findings(Finding *f);
