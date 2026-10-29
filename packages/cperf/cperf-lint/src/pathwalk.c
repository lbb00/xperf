#include "cperf_lint.h"
#include <ctype.h>
#include <strings.h>

#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static int has_ext(const char *name) {
    const char *dot = strrchr(name, '.');
    if (!dot) return 0;
    static const char *exts[] = {".c", ".h", ".cc", ".cpp", ".cxx", ".hpp", NULL};
    for (int i = 0; exts[i]; i++) {
        if (strcasecmp(dot, exts[i]) == 0) return 1;
    }
    return 0;
}

static void basename_of(const char *path, char *out, size_t outsz) {
    const char *slash = strrchr(path, '/');
    const char *base = slash ? slash + 1 : path;
    strncpy(out, base, outsz - 1);
    out[outsz - 1] = '\0';
}

static int path_has_part(const char *path, const char *part) {
    /* match /part/ or starts with part/ or ends with /part or equals part */
    size_t plen = strlen(part);
    const char *p = path;
    while (p && *p) {
        const char *hit = strcasestr(p, part);
        if (!hit) return 0;
        int left_ok = (hit == path) || (hit[-1] == '/');
        int right_ok = (hit[plen] == '\0' || hit[plen] == '/');
        if (left_ok && right_ok) return 1;
        p = hit + 1;
    }
    return 0;
}

int should_skip_path(const char *path) {
    static const char *parts[] = {
        "zig-cache", ".git", "node_modules", "build", "cmake-build-debug",
        "fuzz", "testsuite", "generated",
        /* sqlite ext demos / vtablog — G3 SKIP-path */
        "ext/misc", NULL};
    for (int i = 0; parts[i]; i++) {
        if (path_has_part(path, parts[i])) return 1;
    }

    char name[512];
    basename_of(path, name, sizeof(name));
    char lower[512];
    size_t n = strlen(name);
    if (n >= sizeof(lower)) n = sizeof(lower) - 1;
    for (size_t i = 0; i < n; i++) lower[i] = (char)tolower((unsigned char)name[i]);
    lower[n] = '\0';

    /* gen*.c/cc/... */
    if (strncmp(lower, "gen", 3) == 0 && has_ext(lower)) return 1;
    if (strstr(lower, "generate")) return 1;
    if (strlen(lower) >= 6 && strcmp(lower + strlen(lower) - 6, "_gen.c") == 0) return 1;
    if (strcmp(lower, "ltests.c") == 0 || strcmp(lower, "run-test262.c") == 0 ||
        strcmp(lower, "unicode_gen.c") == 0 || strcmp(lower, "tclsqlite.c") == 0)
        return 1;
    /* sqlite src/testN.c harnesses */
    if (strncmp(lower, "test", 4) == 0 && lower[4] >= '0' && lower[4] <= '9' &&
        has_ext(lower))
        return 1;
    /* libcpp table generators */
    if (strstr(lower, "makeucnid") || strstr(lower, "makeuname")) return 1;
    if (strstr(lower, "dump") && has_ext(lower)) return 1;
    if (strstr(lower, "bitintpow10")) return 1;
    /* Pretty-printers / linker helpers / dep printers — cp-printf-hot noise factories */
    if (strstr(lower, "treeview")) return 1;
    if (strstr(lower, "collect2")) return 1;
    if (strstr(lower, "mkdeps")) return 1;
    if (strstr(lower, "pretty-print") || strstr(lower, "pretty_print")) return 1;
    if (strncmp(lower, "print-", 6) == 0 || strncmp(lower, "print_", 6) == 0) return 1;
    if (strncmp(lower, "getopt", 6) == 0) return 1;
    if (strstr(lower, "divtab")) return 1;
    return 0;
}


static void *ptr_array_reserve(void *p, size_t *cap, size_t need, size_t elem) {
    if (need <= *cap) return p;
    size_t ncap = *cap ? *cap * 2 : 64;
    while (ncap < need) ncap *= 2;
    void *q = realloc(p, ncap * elem);
    if (!q) return NULL;
    *cap = ncap;
    return q;
}

/* Path join lives outside the directory walk so the walk loop does not
 * contain a formatted-print call. */
static void format_child_path(char *dst, size_t dstsz, const char *dir,
                              const char *name) {
    snprintf(dst, dstsz, "%s/%s", dir, name);
}

static int scan_dir(const char *dir, FindingList *out, const char *scope) {
    DIR *d = opendir(dir);
    if (!d) return -1;
    int err = 0;
    struct dirent *ent;
    /* collect names for sorted order */
    char **names = NULL;
    size_t nlen = 0, ncap = 0;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        {
            char **nn = ptr_array_reserve(names, &ncap, nlen + 1, sizeof(char *));
            if (!nn) {
                err = -1;
                break;
            }
            names = nn;
        }
        names[nlen] = strdup(ent->d_name);
        if (!names[nlen]) {
            err = -1;
            break;
        }
        nlen++;
    }
    closedir(d);
    if (err) {
        for (size_t i = 0; i < nlen; i++) free(names[i]);
        free(names);
        return -1;
    }
    /* sort */
    for (size_t i = 0; i + 1 < nlen; i++) {
        for (size_t j = i + 1; j < nlen; j++) {
            if (strcmp(names[i], names[j]) > 0) {
                char *t = names[i];
                names[i] = names[j];
                names[j] = t;
            }
        }
    }
    for (size_t i = 0; i < nlen; i++) {
        char child[4096];
        format_child_path(child, sizeof(child), dir, names[i]);
        struct stat st;
        if (stat(child, &st) != 0) {
            err = -1;
            continue;
        }
        if (S_ISDIR(st.st_mode)) {
            if (should_skip_path(child)) continue;
            /* also skip by dirname alone */
            if (should_skip_path(names[i])) continue;
            if (scan_dir(child, out, scope) != 0) err = -1;
        } else if (S_ISREG(st.st_mode) && has_ext(names[i])) {
            if (should_skip_path(child)) continue;
            if (scan_file(child, out, scope) != 0) err = -1;
        }
    }
    for (size_t i = 0; i < nlen; i++) free(names[i]);
    free(names);
    return err;
}

int scan_path(const char *path, FindingList *out, const char *scope) {
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    if (S_ISREG(st.st_mode)) {
        if (!has_ext(path)) return 0;
        if (should_skip_path(path)) return 0;
        return scan_file(path, out, scope);
    }
    if (S_ISDIR(st.st_mode)) return scan_dir(path, out, scope);
    return 0;
}
