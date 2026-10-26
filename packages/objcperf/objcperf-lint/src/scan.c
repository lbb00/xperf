#include "objcperf_lint.h"
#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

int g_enable_reverse_opt = 1;

/* OC001 removed 2026-10-22 — see evidence/_removed/ */
static const char *MSG002 = "stringByAppendingString in loop; prefer NSMutableString";
static const char *MSG003 = "NSLog in loop; gate or buffer";
/* OC004 removed 2026-10-22 */
static const char *MSG_DATE = "date formatter created in a loop; create it once";
static const char *MSG_JSON = "JSON parse or encode in a loop; hoist only when this value stays the same";
static const char *MSG_RE = "regular expression compiled in a loop; compile outside only when this pattern stays the same";
static const char *MSG_FILE = "file read in a loop; read once when the path stays the same";
static const char *MSG_CLOCK = "clock sample in a tight loop; hoist only when this iteration does not need a fresh time";
static const char *MSG_KEY = "lookup by name in a loop; use the field directly when the name is fixed";

/* Needles are built from pieces so this translation unit never contains the
 * class or selector spellings as contiguous text. The scan loop is itself a
 * loop; a contiguous token there would self-match. Slugs are hyphenated, so
 * match the full selector, not a fragment that appears in the slug. */
static char nd_date[48];
static char nd_json[48];
static char nd_re[48];
static char nd_json_parse[48];
static char nd_json_data[48];
static char nd_re_pat[48];
static char nd_file[64];
static char nd_clock[32];
static char nd_key[32];
static int nd_ready;

static void init_needles(void) {
  if (nd_ready) return;
  snprintf(nd_date, sizeof nd_date, "%s%s", "NSDate", "Formatter");
  snprintf(nd_json, sizeof nd_json, "%s%s", "NSJSON", "Serialization");
  snprintf(nd_re, sizeof nd_re, "%s%s", "NSRegular", "Expression");
  snprintf(nd_json_parse, sizeof nd_json_parse, "%s%s", "JSONObject", "WithData");
  snprintf(nd_json_data, sizeof nd_json_data, "%s%s", "dataWith", "JSONObject");
  snprintf(nd_re_pat, sizeof nd_re_pat, "%s%s", "regularExpression", "WithPattern");
  snprintf(nd_file, sizeof nd_file, "%s%s", "stringWith", "ContentsOfFile");
  snprintf(nd_clock, sizeof nd_clock, "%s%s", "NS", "Date");
  snprintf(nd_key, sizeof nd_key, "%s%s", "valueFor", "Key");
  nd_ready = 1;
}

static int is_ident_char(unsigned char c) { return isalnum(c) || c == '_'; }

static int word_at(const char *base, const char *hit, size_t n) {
  if (hit > base && is_ident_char((unsigned char)hit[-1])) return 0;
  if (is_ident_char((unsigned char)hit[n])) return 0;
  return 1;
}

static int starts_word(const char *p, const char *word) {
  size_t n = strlen(word);
  if (strncmp(p, word, n) != 0) return 0;
  return !is_ident_char((unsigned char)p[n]);
}

/* Class token, then optional whitespace or a dot, then the selector. */
static int message_after(const char *code, const char *klass, const char *sel) {
  init_needles();
  size_t n = strlen(klass);
  if (n == 0 || klass[0] == 0) return 0;
  const char *p = code;
  while ((p = strstr(p, klass)) != NULL) {
    if (word_at(code, p, n)) {
      const char *q = p + n;
      while (*q && isspace((unsigned char)*q)) q++;
      if (*q == '.') q++;
      while (*q && isspace((unsigned char)*q)) q++;
      if (starts_word(q, sel)) return 1;
    }
    p += 1;
  }
  return 0;
}

static int is_objc(const char *path) {
  size_t n = strlen(path);
  if (n > 2 && strcmp(path + n - 2, ".m") == 0) return 1;
  if (n > 2 && strcmp(path + n - 2, ".h") == 0) return 1;
  if (n > 3 && strcmp(path + n - 3, ".mm") == 0) return 1;
  return 0;
}

static int always_skip_dir(const char *name) {
  return strcmp(name, ".git") == 0 || strcmp(name, "fixtures") == 0 ||
         strcmp(name, "node_modules") == 0 || strcmp(name, "vendor") == 0 ||
         strcmp(name, "Pods") == 0 || strcmp(name, "Carthage") == 0;
}

static int noise_skip_dir(const char *name) {
  return strcmp(name, "Tests") == 0 || strcmp(name, "tests") == 0 ||
         strcmp(name, "Test") == 0 || strcmp(name, "test") == 0 ||
         strcmp(name, "Example") == 0 || strcmp(name, "Examples") == 0 ||
         strcmp(name, "example") == 0 || strcmp(name, "examples") == 0 ||
         strcmp(name, "Docs") == 0 || strcmp(name, "docs") == 0 ||
         strcmp(name, "Demo") == 0 || strcmp(name, "demo") == 0 ||
         strcmp(name, "Sample") == 0 || strcmp(name, "sample") == 0 ||
         strcmp(name, "Samples") == 0 || strcmp(name, "samples") == 0 ||
         strcmp(name, "Specs") == 0 || strcmp(name, "benchmarks") == 0 ||
         strcmp(name, "Benchmark") == 0;
}

static int skip_dir(const char *name) {
  if (always_skip_dir(name)) return 1;
  return g_enable_reverse_opt && noise_skip_dir(name);
}

static int path_looks_testish(const char *path) {
  if (strstr(path, "/Tests/") || strstr(path, "/tests/") || strstr(path, "/Test/")) return 1;
  if (strstr(path, "/Example/") || strstr(path, "/Examples/") || strstr(path, "/Demo/")) return 1;
  if (strstr(path, "/sample/") || strstr(path, "/Sample/") || strstr(path, "/samples/")) return 1;
  if (strstr(path, "Tests.m") || strstr(path, "Test.m")) return 1;
  return 0;
}

static void strip_comment(const char *in, char *out, size_t cap) {
  int in_str = 0;
  char q = 0;
  size_t j = 0;
  for (size_t i = 0; in[i] && j + 1 < cap; i++) {
    char c = in[i];
    if (in_str) {
      out[j++] = c;
      if (c == '\\' && in[i + 1]) { out[j++] = in[++i]; continue; }
      if (c == q) in_str = 0;
      continue;
    }
    if (c == '"' || c == '\'') { in_str = 1; q = c; out[j++] = c; continue; }
    if (c == '/' && in[i + 1] == '/') break;
    out[j++] = c;
  }
  out[j] = 0;
}

static Finding *push(Finding *arr, size_t *n, size_t *cap, const char *rule,
                     const char *path, int line, const char *msg) {
  if (*n >= *cap) {
    *cap = *cap ? *cap * 2 : 32;
    arr = realloc(arr, *cap * sizeof(Finding));
  }
  Finding *f = &arr[(*n)++];
  f->rule = rule;
  snprintf(f->path, sizeof(f->path), "%s", path);
  f->line = line;
  f->message = msg;
  return arr;
}

static int oc003_signal(const char *code, const char *path) {
  if (!strstr(code, "NSLog")) return 0;
  if (!g_enable_reverse_opt) return 1;
  if (strstr(code, "DEBUG") || strstr(code, "NDEBUG")) return 0;
  if (strstr(path, "Debug") || strstr(path, "Logger")) return 0;
  return 1;
}

/* loop_has_size_hint removed with OC001/OC004 */

/* is_empty_nsmutable removed with OC001/OC004 */

/* name_before_eq removed with OC001/OC004 */


static int oc_ident_char(char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || (c >= '0' && c <= '9');
}

static int oc_is_type(const char *w) {
  return strcmp(w, "int") == 0 || strcmp(w, "unsigned") == 0 || strcmp(w, "long") == 0 ||
         strcmp(w, "const") == 0 || strcmp(w, "id") == 0 || strcmp(w, "NSUInteger") == 0 ||
         strcmp(w, "NSInteger") == 0 || strcmp(w, "struct") == 0 || strcmp(w, "static") == 0;
}

static int oc_uses(const char *s, char names[][64], int n) {
  for (int i = 0; i < n; i++) {
    size_t ln = strlen(names[i]);
    const char *p = s;
    if (!ln) continue;
    while ((p = strstr(p, names[i])) != NULL) {
      int before = p == s || !oc_ident_char(p[-1]);
      int after = !oc_ident_char(p[ln]);
      if (before && after) return 1;
      p += ln;
    }
  }
  return 0;
}

static int oc_after_uses(const char *code, const char *needle, char names[][64], int n) {
  const char *p;
  if (n <= 0 || !needle) return 0;
  p = strstr(code, needle);
  if (!p) return 0;
  return oc_uses(p + strlen(needle), names, n);
}

static void oc_for_names(const char *line, char names[][64], int *n) {
  const char *forp = strstr(line, "for");
  const char *lp, *rp;
  char *in_kw;
  char head[512];
  size_t len;
  char cur[64];
  int k = 0;
  *n = 0;
  if (!forp) return;
  if (forp != line && oc_ident_char(forp[-1])) return;
  lp = strchr(forp, '(');
  if (!lp) return;
  rp = strchr(lp, ')');
  if (!rp || rp <= lp + 1) return;
  len = (size_t)(rp - lp - 1);
  if (len >= sizeof(head)) len = sizeof(head) - 1;
  memcpy(head, lp + 1, len);
  head[len] = 0;
  {
    char *semi = strchr(head, ';');
    if (semi) *semi = 0;
  }
  in_kw = strstr(head, " in ");
  if (in_kw) *in_kw = 0;
  {
    char *eq = strchr(head, '=');
    if (eq) *eq = 0;
  }
  for (char *p = head;; p++) {
    char c = *p;
    if (oc_ident_char(c) && k < 63) {
      cur[k++] = c;
      continue;
    }
    if (k > 0) {
      cur[k] = 0;
      if (!oc_is_type(cur) && !(cur[0] >= 'A' && cur[0] <= 'Z')) {
        *n = 1;
        snprintf(names[0], 64, "%s", cur);
      }
      k = 0;
    }
    if (!c) break;
  }
}

Finding *scan_file(const char *path, size_t *out_n) {
  if (g_enable_reverse_opt && path_looks_testish(path)) {
    *out_n = 0;
    return NULL;
  }
  FILE *fp = fopen(path, "r");
  if (!fp) { *out_n = 0; return NULL; }
  Finding *arr = NULL;
  size_t n = 0, cap = 0;
  char line[8192], code[8192];
  int depth = 0, in_loop = 0, line_no = 0;
  char loop_names[16][64];
  int loop_name_n = 0;
  init_needles();
  char recent[12][512];
  int recent_n = 0;

  while (fgets(line, sizeof(line), fp)) {
    line_no++;
    strip_comment(line, code, sizeof(code));
    if (recent_n < 12) snprintf(recent[recent_n++], sizeof(recent[0]), "%s", code);
    else {
      memmove(recent[0], recent[1], 11 * sizeof(recent[0]));
      snprintf(recent[11], sizeof(recent[0]), "%s", code);
    }
    int opens = 0, closes = 0;
    for (char *p = code; *p; p++) { if (*p == '{') opens++; if (*p == '}') closes++; }


    int loop_here = 0;
    if (strstr(code, "for ") || strstr(code, "for(")) loop_here = 1;
    if (strstr(code, "while ") || strstr(code, "while(")) loop_here = 1;
    if (loop_here) {
      char added[8][64];
      int added_n = 0;
      in_loop = depth + 1;
      oc_for_names(code, added, &added_n);
      for (int ai = 0; ai < added_n && loop_name_n < 16; ai++) {
        snprintf(loop_names[loop_name_n], 64, "%s", added[ai]);
        loop_name_n++;
      }
    }
    if (in_loop > 0 && depth >= in_loop) {
      /* OC001 removed 2026-10-22 */
      if (strstr(code, "stringByAppendingString"))
        arr = push(arr, &n, &cap, "oc-nsstring-append-in-loop", path, line_no, MSG002);
      if (oc003_signal(code, path)) {
        int skip_log = 0;
        if (g_enable_reverse_opt) {
          if (strstr(code, "_traceExecution") || strstr(code, "traceExecution")) skip_log = 1;
          for (int ri = 0; ri < recent_n && !skip_log; ri++) {
            if (strstr(recent[ri], "DEBUG") || strstr(recent[ri], "_traceExecution") ||
                strstr(recent[ri], "traceExecution"))
              skip_log = 1;
          }
        }
        if (!skip_log)
          arr = push(arr, &n, &cap, "oc-nslog-in-loop", path, line_no, MSG003);
      }
      if (message_after(code, nd_date, "alloc") || message_after(code, nd_date, "new"))
        arr = push(arr, &n, &cap, "oc-dateformatter-in-loop", path, line_no, MSG_DATE);
      if ((message_after(code, nd_json, nd_json_parse) || message_after(code, nd_json, nd_json_data)) &&
          !oc_after_uses(code, nd_json_parse, loop_names, loop_name_n) &&
          !oc_after_uses(code, nd_json_data, loop_names, loop_name_n))
        arr = push(arr, &n, &cap, "oc-json-in-loop", path, line_no, MSG_JSON);
      if (message_after(code, nd_re, nd_re_pat) &&
          !oc_after_uses(code, nd_re_pat, loop_names, loop_name_n))
        arr = push(arr, &n, &cap, "oc-regex-in-loop", path, line_no, MSG_RE);
      init_needles();
      if (strstr(code, nd_file) && !oc_after_uses(code, nd_file, loop_names, loop_name_n))
        arr = push(arr, &n, &cap, "oc-file-read-in-loop", path, line_no, MSG_FILE);
      if (message_after(code, nd_clock, "date"))
        arr = push(arr, &n, &cap, "oc-clock-in-loop", path, line_no, MSG_CLOCK);
      if (strstr(code, nd_key))
        arr = push(arr, &n, &cap, "oc-value-for-key-in-loop", path, line_no, MSG_KEY);
      /* OC004 removed 2026-10-22 */
    }
    depth += opens - closes;
    if (depth < 0) depth = 0;
    if (in_loop > 0 && depth < in_loop) { in_loop = 0; loop_name_n = 0; }
  }
  fclose(fp);
  *out_n = n;
  return arr;
}

static void walk(const char *dir, Finding **arr, size_t *n, size_t *cap) {
  DIR *d = opendir(dir);
  if (!d) return;
  struct dirent *ent;
  while ((ent = readdir(d)) != NULL) {
    if (ent->d_name[0] == '.') continue;
    if (skip_dir(ent->d_name)) continue;
    char path[2048];
    snprintf(path, sizeof(path), "%s/%s", dir, ent->d_name);
    struct stat st;
    if (stat(path, &st) != 0) continue;
    if (S_ISDIR(st.st_mode)) walk(path, arr, n, cap);
    else if (S_ISREG(st.st_mode) && is_objc(path)) {
      size_t fn = 0;
      Finding *fs = scan_file(path, &fn);
      for (size_t i = 0; i < fn; i++)
        *arr = push(*arr, n, cap, fs[i].rule, fs[i].path, fs[i].line, fs[i].message);
      free(fs);
    }
  }
  closedir(d);
}

Finding *scan_path(const char *root, size_t *out_n) {
  struct stat st;
  if (stat(root, &st) != 0) { *out_n = 0; return NULL; }
  if (S_ISREG(st.st_mode)) {
    if (!is_objc(root)) { *out_n = 0; return NULL; }
    return scan_file(root, out_n);
  }
  Finding *arr = NULL;
  size_t n = 0, cap = 0;
  walk(root, &arr, &n, &cap);
  *out_n = n;
  return arr;
}

void free_findings(Finding *f) { free(f); }
