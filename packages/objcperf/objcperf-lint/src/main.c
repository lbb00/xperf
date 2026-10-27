#include "objcperf_lint.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum { Off = 0, Hint = 1, Error = 2 } Sev;

static Sev parse_sev(const char *s) {
  if (strcmp(s, "error") == 0) return Error;
  if (strcmp(s, "hint") == 0) return Hint;
  if (strcmp(s, "off") == 0) return Off;
  return (Sev)-1;
}
static const char *sev_name(Sev s) {
  switch (s) { case Error: return "error"; case Hint: return "hint"; default: return "off"; }
}
static void usage(int code) {
  fprintf(stderr, "Usage: objcperf-lint PATH... [options]\n  --format text|json\n  --severity RULE=error|hint|off\n  --scope all|loop     (default: all; loop = former in-loop-only)\n  --strict-hints\n  --no-fail\n  --raw-paths          include Tests/Examples (baseline dumps)\n");
  exit(code);
}
static int apply_sev(Sev *rs, const char *spec) {
  char buf[64];
  snprintf(buf, sizeof(buf), "%s", spec);
  char *eq = strchr(buf, '=');
  if (!eq) return 0;
  *eq = 0;
  Sev s = parse_sev(eq + 1);
  if ((int)s < 0) return 0;
  if (strcmp(buf, "oc-nsstring-append-hot") == 0) rs[0] = s;
  else if (strcmp(buf, "oc-nslog-hot") == 0) rs[1] = s;
  else if (strcmp(buf, "oc-dateformatter-hot") == 0) rs[2] = s;
  else if (strcmp(buf, "oc-json-hot") == 0) rs[3] = s;
  else if (strcmp(buf, "oc-regex-hot") == 0) rs[4] = s;
  else if (strcmp(buf, "oc-file-read-hot") == 0) rs[5] = s;
  else if (strcmp(buf, "oc-clock-hot") == 0) rs[6] = s;
  else if (strcmp(buf, "oc-value-for-key-hot") == 0) rs[7] = s;
  else return 0;
  return 1;
}
static Sev lookup(Sev *rs, const char *rule) {
  if (strcmp(rule, "oc-nsstring-append-hot") == 0) return rs[0];
  if (strcmp(rule, "oc-nslog-hot") == 0) return rs[1];
  if (strcmp(rule, "oc-dateformatter-hot") == 0) return rs[2];
  if (strcmp(rule, "oc-json-hot") == 0) return rs[3];
  if (strcmp(rule, "oc-regex-hot") == 0) return rs[4];
  if (strcmp(rule, "oc-file-read-hot") == 0) return rs[5];
  if (strcmp(rule, "oc-clock-hot") == 0) return rs[6];
  if (strcmp(rule, "oc-value-for-key-hot") == 0) return rs[7];
  return Hint; /* unknown stays hint, never error */
}

int main(int argc, char **argv) {
  if (argc < 2) usage(2);
  /* append, log stay off; the three 2026-10-23 smells default to hint */
  Sev rs[8] = {Off, Off, Hint, Hint, Hint, Hint, Hint, Hint};
  const char *format = "text";
  int strict_hints = 0, no_fail = 0;
  char *paths[64];
  int npaths = 0;
  for (int i = 1; i < argc; i++) {
    char *a = argv[i];
    if (strcmp(a, "-h") == 0 || strcmp(a, "--help") == 0) usage(0);
    if (strcmp(a, "--format") == 0 && i + 1 < argc) { format = argv[++i]; continue; }
    if (strncmp(a, "--format=", 9) == 0) { format = a + 9; continue; }
    if (strcmp(a, "--severity") == 0 && i + 1 < argc) { if (!apply_sev(rs, argv[++i])) usage(2); continue; }
    if (strncmp(a, "--severity=", 11) == 0) { if (!apply_sev(rs, a + 11)) usage(2); continue; }
    if (strcmp(a, "--strict-hints") == 0) { strict_hints = 1; continue; }
    if (strcmp(a, "--no-fail") == 0) { no_fail = 1; continue; }
    if (strcmp(a, "--raw-paths") == 0) { g_enable_reverse_opt = 0; continue; }
    if (a[0] == '-') usage(2);
    if (npaths < 64) paths[npaths++] = a;
  }
  if (npaths == 0) usage(2);

  Finding *all = NULL;
  size_t nall = 0, call = 0;
  for (int i = 0; i < npaths; i++) {
    size_t fn = 0;
    Finding *fs = scan_path(paths[i], &fn);
    for (size_t j = 0; j < fn; j++) {
      if (nall >= call) { call = call ? call * 2 : 64; all = realloc(all, call * sizeof(Finding)); }
      all[nall++] = fs[j];
    }
    free(fs);
  }

  int nerr = 0, nhint = 0;
  if (strcmp(format, "json") == 0) {
    printf("[");
    int first = 1;
    for (size_t i = 0; i < nall; i++) {
      Sev s = lookup(rs, all[i].rule);
      if (s == Off) continue;
      if (s == Error) nerr++; else nhint++;
      if (!first) putchar(',');
      first = 0;
      printf("{\"rule\":\"%s\",\"severity\":\"%s\",\"path\":\"%s\",\"line\":%d,\"message\":\"%s\"}",
             all[i].rule, sev_name(s), all[i].path, all[i].line, all[i].message);
    }
    printf("]\n");
  } else {
    for (size_t i = 0; i < nall; i++) {
      Sev s = lookup(rs, all[i].rule);
      if (s == Off) continue;
      if (s == Error) nerr++; else nhint++;
      printf("%s:%d: %s %s: %s\n", all[i].path, all[i].line, sev_name(s), all[i].rule, all[i].message);
    }
    int shown = nerr + nhint;
    if (shown) fprintf(stderr, "%d finding(s) (%d error, %d hint)\n", shown, nerr, nhint);
    else fprintf(stderr, "ok\n");
  }
  free(all);
  if (no_fail) return 0;
  if (nerr > 0 || (strict_hints && nhint > 0)) return 1;
  return 0;
}
