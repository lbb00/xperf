#include "cperf_lint.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LINE 65536
#define MAX_STACK 512
#define MAX_FUNC 256
#define MAX_PREV 4096

static int strip_comments_line(const char *raw, char *out, size_t outsz, int in_block) {
    size_t o = 0;
    size_t i = 0;
    size_t n = strlen(raw);
    int in_line = 0;
    while (i < n && o + 1 < outsz) {
        if (in_block) {
            if (i + 1 < n && raw[i] == '*' && raw[i + 1] == '/') {
                out[o++] = ' ';
                out[o++] = ' ';
                i += 2;
                in_block = 0;
                continue;
            }
            out[o++] = ' ';
            i++;
            continue;
        }
        if (in_line) {
            break;
        }
        if (raw[i] == '/' && i + 1 < n && raw[i + 1] == '*') {
            out[o++] = ' ';
            out[o++] = ' ';
            i += 2;
            in_block = 1;
            continue;
        }
        if (raw[i] == '/' && i + 1 < n && raw[i + 1] == '/') {
            break;
        }
        out[o++] = raw[i++];
    }
    out[o] = '\0';
    return in_block;
}

static int starts_with_kw(const char *s, const char *kw) {
    size_t n = strlen(kw);
    if (strncmp(s, kw, n) != 0) return 0;
    return !cperf_is_ident(s[n]);
}

static int is_ctrl_or_call(const char *name) {
    static const char *ctrl[] = {
        "if", "while", "for", "switch", "return", "sizeof", "typeof",
        "elif", "else", "do", "case", NULL};
    static const char *calls[] = {
        "printf", "fprintf", "puts", "fputs", "dprintf",
        "malloc", "calloc", "realloc", "memcpy", "memmove", "memset", "assert",
        "sprintf", "snprintf", "fopen", "gettimeofday", "clock_gettime",
        "reg" "comp",
        NULL};
    for (int i = 0; ctrl[i]; i++)
        if (strcmp(name, ctrl[i]) == 0) return 1;
    for (int i = 0; calls[i]; i++)
        if (strcmp(name, calls[i]) == 0) return 1;
    return 0;
}


static int bind_ident_char(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || (c >= '0' && c <= '9');
}

static int bind_is_type(const char *w) {
    return strcmp(w, "int") == 0 || strcmp(w, "unsigned") == 0 || strcmp(w, "long") == 0 ||
           strcmp(w, "short") == 0 || strcmp(w, "char") == 0 || strcmp(w, "const") == 0 ||
           strcmp(w, "size_t") == 0 || strcmp(w, "struct") == 0 || strcmp(w, "signed") == 0 ||
           strcmp(w, "volatile") == 0 || strcmp(w, "double") == 0 || strcmp(w, "float") == 0;
}

static int line_uses_bind(const char *s, char names[][64], int n) {
    for (int i = 0; i < n; i++) {
        size_t ln = strlen(names[i]);
        const char *p = s;
        if (ln == 0) continue;
        while ((p = strstr(p, names[i])) != NULL) {
            int before = (p == s) || !bind_ident_char(p[-1]);
            int after = !bind_ident_char(p[ln]);
            if (before && after) return 1;
            p += ln;
        }
    }
    return 0;
}

static int named_call_uses_bind(const char *line, const char **calls, char names[][64], int n) {
    if (n <= 0) return 0;
    for (int i = 0; calls[i]; i++) {
        const char *p = cperf_find_word(line, calls[i]);
        if (!p) continue;
        const char *lp = strchr(p, '(');
        if (!lp) continue;
        if (line_uses_bind(lp, names, n)) return 1;
    }
    return 0;
}

static void parse_for_binds(const char *line, char names[][64], int *n) {
    *n = 0;
    const char *forp = cperf_find_word(line, "for");
    if (!forp) return;
    const char *lp = strchr(forp, '(');
    if (!lp) return;
    const char *rp = strchr(lp, ')');
    if (!rp || rp <= lp + 1) return;
    char head[512];
    size_t len = (size_t)(rp - lp - 1);
    if (len >= sizeof(head)) len = sizeof(head) - 1;
    memcpy(head, lp + 1, len);
    head[len] = 0;
    char *semi = strchr(head, ';');
    if (semi) *semi = 0;
    char *colon = strchr(head, ':');
    if (colon) *colon = 0;
    char *eq = strchr(head, '=');
    if (eq) *eq = 0;
    char cur[64];
    int k = 0;
    for (char *p = head; ; p++) {
        char c = *p;
        if (bind_ident_char(c) && k < 63) {
            cur[k++] = c;
            continue;
        }
        if (k > 0) {
            cur[k] = 0;
            if (!bind_is_type(cur) && *n < 8)
                snprintf(names[*n], 64, "%s", cur), (*n)++;
            k = 0;
        }
        if (c == 0) break;
    }
}

static int line_has_loop_kw(const char *line) {
    return cperf_find_word(line, "for") || cperf_find_word(line, "while") ||
           cperf_find_word(line, "do");
}

static const char *skip_ws(const char *s) {
    while (*s && isspace((unsigned char)*s)) s++;
    return s;
}

/* Match malloc|calloc|realloc( */
static int has_alloc_call(const char *line) {
    static const char *names[] = {"malloc", "calloc", "realloc", NULL};
    for (int i = 0; names[i]; i++) {
        const char *p = cperf_find_word(line, names[i]);
        if (!p) continue;
        p += strlen(names[i]);
        p = skip_ws(p);
        if (*p == '(') return 1;
    }
    return 0;
}

static int has_return_alloc(const char *line) {
    const char *s = skip_ws(line);
    if (!starts_with_kw(s, "return")) return 0;
    s += 6;
    s = skip_ws(s);
    return has_alloc_call(s);
}

/* printf|fprintf|puts|fputs|dprintf( */
static int has_print_call(const char *line) {
    static const char *names[] = {"printf", "fprintf", "puts", "fputs", "dprintf", NULL};
    for (int i = 0; names[i]; i++) {
        const char *p = cperf_find_word(line, names[i]);
        if (!p) continue;
        p += strlen(names[i]);
        p = skip_ws(p);
        if (*p == '(') return 1;
    }
    return 0;
}

/* Refine: realloc grow heuristic:
 * realloc\s*\(\s*[^,]+,\s*[^)]*(\+\s*1|\b(?:old_|new_)?size\s*\+\s*1|len\s*\+\s*1|n\s*\+\s*1)
 */
static int has_realloc_grow2(const char *line) {
    const char *p = cperf_find_word(line, "realloc");
    if (!p) return 0;
    p += 7;
    while (*p && isspace((unsigned char)*p)) p++;
    if (*p != '(') return 0;
    p++;
    /* skip first arg to comma */
    int depth = 1;
    int seen_comma = 0;
    for (; *p && depth > 0; p++) {
        if (*p == '(') depth++;
        else if (*p == ')') {
            depth--;
            if (depth == 0) break;
        } else if (*p == ',' && depth == 1) {
            seen_comma = 1;
            p++;
            break;
        }
    }
    if (!seen_comma) return 0;
    /* second arg region until matching close at depth 0 — we already advanced past comma */
    const char *arg2 = p;
    /* check patterns in arg2 until we hit unbalanced ) — just search substring */
    char buf[1024];
    size_t i = 0;
    depth = 1; /* we are inside realloc( */
    for (const char *q = arg2; *q && i + 1 < sizeof(buf); q++) {
        if (*q == '(') depth++;
        else if (*q == ')') {
            depth--;
            if (depth == 0) break;
        }
        buf[i++] = *q;
    }
    buf[i] = '\0';
    /* Header-slot FP (G3 emutls): realloc(p, (cap + 1) * sizeof T) is not
     * byte-wise n+1 growth — +1 reserves a length/header element. */
    if (strstr(buf, "sizeof")) {
        int plus1 = 0;
        for (char *s = buf; *s; s++) {
            if (*s == '+') {
                char *t = s + 1;
                while (*t && isspace((unsigned char)*t)) t++;
                if (*t == '1' && !isdigit((unsigned char)t[1])) plus1 = 1;
            }
        }
        if (plus1) return 0;
    }
    /* +\s*1 anywhere in second arg is enough for fixtures; also size+1 etc. */
    for (char *s = buf; *s; s++) {
        if (*s == '+') {
            char *t = s + 1;
            while (*t && isspace((unsigned char)*t)) t++;
            if (*t == '1' && !isdigit((unsigned char)t[1])) return 1;
        }
    }
    return 0;
}

static int is_dumpish_token(const char *rest) {
    /* Trim and detect dead #if 0 / #if false first (G3: dtoa/lua/#if 0 DOC). */
    const char *r = rest;
    while (*r && isspace((unsigned char)*r)) r++;
    if (*r == '0') {
        char n = r[1];
        if (!n || isspace((unsigned char)n) || n == '/' || n == '\\') return 1;
    }
    if (strncmp(r, "false", 5) == 0 || strncmp(r, "FALSE", 5) == 0) return 1;
    /* #ifdef TEST / #if TEST — local harness mains (quickjs libregexp) */
    if (strcmp(r, "TEST") == 0 || strncmp(r, "TEST ", 5) == 0 ||
        strncmp(r, "TEST/", 5) == 0)
        return 1;
    /* Substring DEBUG/DUMP/TRACE so SQLITE_DEBUG / WHERETRACE / VdbeTrace match
     * (find_word misses FOO_DEBUG because '_' is an ident char). */
    return cperf_ci_strstr(rest, "DUMP") || cperf_ci_strstr(rest, "DEBUG") ||
           cperf_ci_strstr(rest, "TRACE") || cperf_ci_strstr(rest, "ENABLE_") ||
           cperf_find_word_ci(rest, "GATHER_STATISTICS") ||
           cperf_find_word_ci(rest, "ENABLE_CHECKING") ||
           cperf_ci_strstr(rest, "PROFILE") ||
           cperf_ci_strstr(rest, "BITVEC_");
}

static void update_ifdef_stack(int *stack, int *sp, int maxsp, const char *stripped) {
    const char *s = stripped;
    if (*s != '#') return;
    s++;
    while (*s && isspace((unsigned char)*s)) s++;
    const char *kw = s;
    char kwbuf[16];
    size_t ki = 0;
    while (*s && isalpha((unsigned char)*s) && ki + 1 < sizeof(kwbuf)) kwbuf[ki++] = *s++;
    kwbuf[ki] = '\0';
    while (*s && isspace((unsigned char)*s)) s++;
    const char *rest = s;
    int dumpish = is_dumpish_token(rest);

    if (strcmp(kwbuf, "if") == 0 || strcmp(kwbuf, "ifdef") == 0 ||
        strcmp(kwbuf, "ifndef") == 0) {
        if (*sp >= maxsp) return;
        if (strcmp(kwbuf, "ifndef") == 0 && dumpish)
            stack[(*sp)++] = 0;
        else
            stack[(*sp)++] = dumpish ? 1 : 0;
    } else if (strcmp(kwbuf, "elif") == 0) {
        if (*sp > 0) (*sp)--;
        if (*sp < maxsp) stack[(*sp)++] = dumpish ? 1 : 0;
    } else if (strcmp(kwbuf, "else") == 0) {
        if (*sp > 0) {
            int v = stack[--(*sp)];
            stack[(*sp)++] = !v;
        }
    } else if (strcmp(kwbuf, "endif") == 0) {
        if (*sp > 0) (*sp)--;
    }
    (void)kw;
}

static int ifdef_any(const int *stack, int sp) {
    for (int i = 0; i < sp; i++)
        if (stack[i]) return 1;
    return 0;
}

static int is_debug_func(const char *name) {
    if (!name || !*name) return 0;
    if (cperf_ci_strstr(name, "dump") || cperf_ci_strstr(name, "debug") ||
        cperf_ci_strstr(name, "trace") || cperf_ci_strstr(name, "log_") ||
        cperf_ci_strstr(name, "treeview") || cperf_ci_strstr(name, "pprint") ||
        cperf_ci_strstr(name, "pretty"))
        return 1;
    char lower[MAX_FUNC];
    size_t n = strlen(name);
    if (n >= sizeof(lower)) n = sizeof(lower) - 1;
    for (size_t i = 0; i < n; i++) lower[i] = (char)tolower((unsigned char)name[i]);
    lower[n] = '\0';
    /* pretty-printers / AST viewers / show* helpers */
    if (strstr(lower, "print")) return 1;
    if (strstr(lower, "view")) return 1;
    if (n >= 4 && strncmp(lower, "show", 4) == 0) return 1;
    if (n >= 7 && strncmp(lower, "display", 7) == 0) return 1;
    return 0;
}

/* dump_file / *_dump / dump_* / sched_dump / asm_out_file / stderr as word */
static int has_dump_stream(const char *line) {
    if (cperf_find_word(line, "stderr")) return 1;
    if (cperf_find_word(line, "asm_out_file")) return 1;
    if (cperf_find_word(line, "sched_dump")) return 1;
    /* scan identifiers containing dump */
    for (const char *p = line; *p;) {
        if (!cperf_is_ident_start(*p)) {
            p++;
            continue;
        }
        char id[256];
        size_t n = 0;
        while (cperf_is_ident(*p) && n + 1 < sizeof(id)) id[n++] = *p++;
        id[n] = '\0';
        if (cperf_ci_strstr(id, "dump_file") || cperf_ci_strstr(id, "_dump") ||
            (n >= 5 && strncmp(id, "dump_", 5) == 0) || cperf_ci_strstr(id, "dump")) {
            /* dump streams: \w*dump_file|\w*_dump|dump_\w*|sched_dump|asm_out_file|stderr */
            if (cperf_ci_strstr(id, "dump_file") ||
                (n >= 5 && strcmp(id + n - 5, "_dump") == 0) ||
                (n > 5 && strncmp(id, "dump_", 5) == 0) ||
                strcmp(id, "sched_dump") == 0)
                return 1;
            /* also lra_dump_file matched via dump_file substring in \w*dump_file */
            if (cperf_ci_strstr(id, "dump_file")) return 1;
        }
    }
    return 0;
}

static int has_dump_if(const char *prev) {
    const char *p = cperf_find_word(prev, "if");
    if (!p) return 0;
    p += 2;
    p = skip_ws(p);
    if (*p != '(') return 0;
    return has_dump_stream(p);
}

static int should_skip_cp003(const char *line, const char *raw, const char *prev,
                             const char *current_func, int in_dump_ifdef) {
    if (in_dump_ifdef) return 1;
    if (is_debug_func(current_func)) return 1;
    if (has_dump_stream(line)) return 1;
    if (prev && *prev && has_dump_if(prev)) return 1;
    if (prev && prev[0] == '#' && is_dumpish_token(prev)) return 1;
    /* macro continuation */
    size_t rlen = strlen(raw);
    while (rlen > 0 && (raw[rlen - 1] == '\n' || raw[rlen - 1] == '\r' ||
                        isspace((unsigned char)raw[rlen - 1])))
        rlen--;
    if (rlen > 0 && raw[rlen - 1] == '\\') return 1;
    return 0;
}

/* Strip __attribute__((...)) roughly */
static void strip_attributes(char *s) {
    char *p;
    while ((p = strstr(s, "__attribute__")) != NULL) {
        char *q = p + 13;
        q = (char *)skip_ws(q);
        if (*q != '(') {
            *p = ' ';
            continue;
        }
        /* skip nested parens */
        int depth = 0;
        char *r = q;
        for (; *r; r++) {
            if (*r == '(') depth++;
            else if (*r == ')') {
                depth--;
                if (depth == 0) {
                    r++;
                    break;
                }
            }
        }
        memmove(p, r, strlen(r) + 1);
    }
}

static int match_func_prefix(const char *s) {
    /* Starts with type/storage keywords — soft heuristic */
    static const char *prefs[] = {
        "static", "inline", "extern", "const", "unsigned", "signed", "volatile",
        "struct", "enum", "union", "void", "int", "char", "long", "short",
        "float", "double", "bool", "size_t", "ssize_t", "FILE", "tree", "rtx",
        "basic_block", "DEBUG_FUNCTION", "ATTRIBUTE_UNUSED", NULL};
    const char *p = skip_ws(s);
    int saw = 0;
    while (*p) {
        int hit = 0;
        for (int i = 0; prefs[i]; i++) {
            size_t n = strlen(prefs[i]);
            if (strncmp(p, prefs[i], n) == 0 && !cperf_is_ident(p[n])) {
                p += n;
                while (*p && (isspace((unsigned char)*p) || *p == '*' || *p == '&')) p++;
                saw = 1;
                hit = 1;
                break;
            }
        }
        /* uint32_t / JSAtom / __foo */
        if (!hit && (strncmp(p, "uint", 4) == 0 || strncmp(p, "int8", 4) == 0 ||
                     strncmp(p, "int16", 5) == 0 || strncmp(p, "int32", 5) == 0 ||
                     strncmp(p, "int64", 5) == 0 || strncmp(p, "JS", 2) == 0 ||
                     strncmp(p, "__", 2) == 0 || strncmp(p, "vec", 3) == 0 ||
                     strncmp(p, "hash_", 5) == 0)) {
            while (cperf_is_ident(*p)) p++;
            while (*p && (isspace((unsigned char)*p) || *p == '*' || *p == '&')) p++;
            saw = 1;
            hit = 1;
        }
        if (!hit) break;
    }
    return saw;
}

static int is_type_only_line(const char *stripped) {
    /* entire line is type keywords — for prev_type_only */
    char buf[MAX_LINE];
    strncpy(buf, stripped, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    strip_attributes(buf);
    const char *p = skip_ws(buf);
    if (!*p) return 0;
    /* must not contain '(' */
    if (strchr(p, '(')) return 0;
    return match_func_prefix(p);
}

static int looks_like_func_def(const char *line, int prev_type_only, char *out_name,
                              size_t out_sz) {
    char buf[MAX_LINE];
    strncpy(buf, line, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    strip_attributes(buf);
    char *s = (char *)skip_ws(buf);
    if (!*s || *s == '#') return 0;
    /* prototype ending with ); and no { */
    {
        char *t = s + strlen(s);
        while (t > s && isspace((unsigned char)t[-1])) t--;
        if (t > s && t[-1] == ';' && !strchr(s, '{')) {
            /* ) ; */
            char *u = t - 1;
            while (u > s && isspace((unsigned char)u[-1])) u--;
            if (u > s && u[-1] == ')') return 0;
        }
    }
    if (starts_with_kw(s, "if") || starts_with_kw(s, "while") || starts_with_kw(s, "for") ||
        starts_with_kw(s, "switch") || starts_with_kw(s, "return") ||
        starts_with_kw(s, "else"))
        return 0;

    /* C++ method Class::method( */
    for (char *p = s; *p; p++) {
        if (p[0] == ':' && p[1] == ':') {
            char *m = p + 2;
            while (*m && isspace((unsigned char)*m)) m++;
            if (cperf_is_ident_start(*m)) {
                size_t n = 0;
                while (cperf_is_ident(m[n])) n++;
                const char *after = skip_ws(m + n);
                if (*after == '(') {
                    if (n >= out_sz) n = out_sz - 1;
                    memcpy(out_name, m, n);
                    out_name[n] = '\0';
                    return 1;
                }
            }
        }
    }

    /* Find Ident( */
    for (char *p = s; *p; p++) {
        if (!cperf_is_ident_start(*p)) continue;
        char *start = p;
        while (cperf_is_ident(*p)) p++;
        char *end = p;
        const char *after = skip_ws(p);
        if (*after != '(') {
            p = end - 1;
            continue;
        }
        size_t n = (size_t)(end - start);
        char name[MAX_FUNC];
        if (n >= sizeof(name)) n = sizeof(name) - 1;
        memcpy(name, start, n);
        name[n] = '\0';
        if (is_ctrl_or_call(name)) {
            p = end - 1;
            continue;
        }
        if (cperf_ci_strstr(name, "for_each") || cperf_ci_strstr(name, "foreach")) {
            p = end - 1;
            continue;
        }
        /* ALL_CAPS → likely macro (TREE_CODE_CLASS, EXECUTE_IF_…) */
        {
            int letters = 0, upper = 0;
            for (size_t i = 0; name[i]; i++) {
                if (name[i] >= 'A' && name[i] <= 'Z') {
                    letters++;
                    upper++;
                } else if (name[i] >= 'a' && name[i] <= 'z') {
                    letters++;
                }
            }
            if (letters >= 3 && upper == letters) {
                p = end - 1;
                continue;
            }
        }
        /* Call-arg continuation: foo(a,  or  bar(x), */
        {
            char *tend = s + strlen(s);
            while (tend > s && isspace((unsigned char)tend[-1])) tend--;
            if (tend > s && tend[-1] == ',') {
                p = end - 1;
                continue;
            }
        }
        /* before: no = unless operator; also reject ternary call sites */
        int has_eq = 0;
        int has_ternary = 0;
        for (char *q = s; q < start; q++) {
            if (*q == '=') has_eq = 1;
            if (*q == '?') has_ternary = 1;
        }
        if (has_eq && !strstr(s, "operator")) {
            p = end - 1;
            continue;
        }
        if (has_ternary) {
            p = end - 1;
            continue;
        }
        /* Require a type prefix or a previous type-only line (GNU style).
         * Do NOT treat bare Ident( inside bodies as defs — that overwrote
         * current_func with callees like cgraph_inline_failed_string. */
        if (match_func_prefix(s) || (prev_type_only && start == s)) {
            size_t copy = n < out_sz - 1 ? n : out_sz - 1;
            memcpy(out_name, name, copy);
            out_name[copy] = '\0';
            return 1;
        }
        p = end - 1;
    }
    return 0;
}


/* cp-strlen-in-cond: strlen( in for/while *condition* — classic O(n^2) bound recompute. */
static int has_strlen_in_loop_cond(const char *line) {
    const char *p = line;
    while (*p) {
        int is_while = 0;
        if (starts_with_kw(p, "for")) {
            /* for */
            p += 3;
        } else if (starts_with_kw(p, "while")) {
            is_while = 1;
            p += 5;
        } else {
            p++;
            continue;
        }
        p = skip_ws(p);
        if (*p != '(') continue;
        p++; /* inside cond */
        if (is_while) {
            /* whole while (...) condition */
            int depth = 1;
            const char *start = p;
            for (; *p && depth > 0; p++) {
                if (*p == '(') depth++;
                else if (*p == ')') depth--;
            }
            /* scan [start, p) for strlen( */
            for (const char *q = start; q < p; q++) {
                if (starts_with_kw(q, "strlen")) {
                    const char *r = skip_ws(q + 6);
                    if (*r == '(') return 1;
                }
            }
            continue;
        }
        /* for: look at 2nd clause (between first and second ';') */
        {
            int depth = 1;
            int semis = 0;
            const char *clause2 = NULL;
            const char *clause2_end = NULL;
            for (; *p && depth > 0; p++) {
                if (*p == '(') depth++;
                else if (*p == ')') {
                    depth--;
                    if (depth == 0) {
                        if (semis == 1 && clause2 && !clause2_end) clause2_end = p;
                        break;
                    }
                } else if (*p == ';' && depth == 1) {
                    if (semis == 0) {
                        clause2 = p + 1;
                        semis = 1;
                    } else if (semis == 1) {
                        clause2_end = p;
                        semis = 2;
                    }
                }
            }
            if (clause2 && clause2_end) {
                for (const char *q = clause2; q < clause2_end; q++) {
                    if (starts_with_kw(q, "strlen")) {
                        const char *r = skip_ws(q + 6);
                        if (*r == '(') return 1;
                    }
                }
            }
        }
    }
    return 0;
}

static int has_strcat_call(const char *line) {
    static const char *names[] = {"strcat", "strncat", NULL};
    for (int i = 0; names[i]; i++) {
        const char *p = cperf_find_word(line, names[i]);
        if (!p) continue;
        p += strlen(names[i]);
        p = skip_ws(p);
        if (*p == '(') return 1;
    }
    return 0;
}

/* cp-alloc-hot reverse-opt: capacity-doubling realloc is OK-idiom, not per-iter smell. */
static int is_doubling_realloc(const char *line) {
    const char *p = cperf_find_word(line, "realloc");
    if (!p) return 0;
    /* * 2, *2, << 1, <<1 in the line after realloc */
    if (strstr(p, "*2") || strstr(p, "* 2") || strstr(p, "<<1") || strstr(p, "<< 1"))
        return 1;
    if (strstr(p, "*2u") || strstr(p, "* 2u") || strstr(p, "*2U") || strstr(p, "* 2U"))
        return 1;
    return 0;
}

/* Names stay outside scan_file's walk loop. The '(' check is separate so the
 * source never contains the call spelling inside a loop. */
static const char *k_buf_fmt_names[] = {"sprintf", "snprintf", NULL};
static const char *k_file_open_names[] = {"fopen", NULL};
static const char *k_clock_names[] = {"gettimeofday", "clock_gettime", NULL};
/* Pieces stay split so this file never contains the compile token as one word. */
static const char *k_regex_names[] = {"reg" "comp", NULL};

static const char k_msg_buf_fmt[] =
    "formatted buffer write; reuse one buffer — cost adds up even off a hot path";
static const char k_msg_file_open[] =
    "file open; open once when the path stays the same — cost adds up even off a hot path";
static const char k_msg_clock[] =
    "clock sample in a tight loop; hoist only when this iteration does not need a fresh time";
static const char k_msg_regex[] =
    "regular expression compile; compile once when the pattern stays the same — cost adds up even off a hot path";
/* Pieces stay split so this file never contains the stack-call token. */
static const char *k_stack_names[] = {"all" "oca", "__builtin_all" "oca", NULL};
static const char k_msg_stack[] =
    "stack allocation (alloca) that repeats grows until the function returns; reuse one buffer — cost adds up even off a hot path";
static const char k_msg_byvalue[] =
    "large struct passed by value; pass a pointer unless the callee needs its own copy";

/* Cross-TU copies below this size stayed under the 7x bar on this machine. */
#define MIN_BYVALUE_BYTES 512
#define MIN_BYVALUE_FIELDS 4
#define MAX_REC_SIZES 128

typedef struct {
    char name[64];
    int bytes;
    int fields;
} RecSize;

static int decimal_span(const char *s, int *out) {
    if (*s < '0' || *s > '9') return 0;
    int v = 0;
    const char *p = s;
    while (*p >= '0' && *p <= '9') {
        if (v > 200000000) return 0;
        v = v * 10 + (*p - '0');
        p++;
    }
    *out = v;
    return (int)(p - s);
}

static int starts_with_word(const char *s, const char *w);

/* LP64 lower bound. Returns -1 when the leading type is not one we size. */
static int parse_base_width(const char **ps) {
    const char *s = skip_ws(*ps);
    int saw_unsigned = 0;
    for (;;) {
        s = skip_ws(s);
        if (starts_with_word(s, "const")) {
            s += 5;
            continue;
        }
        if (starts_with_word(s, "volatile")) {
            s += 8;
            continue;
        }
        if (starts_with_word(s, "unsigned")) {
            saw_unsigned = 1;
            s += 8;
            continue;
        }
        if (starts_with_word(s, "signed")) {
            s += 6;
            continue;
        }
        break;
    }
    s = skip_ws(s);
    int base = -1;
    if (starts_with_word(s, "char")) {
        base = 1;
        s += 4;
    } else if (starts_with_word(s, "_Bool")) {
        base = 1;
        s += 5;
    } else if (starts_with_word(s, "bool")) {
        base = 1;
        s += 4;
    } else if (starts_with_word(s, "short")) {
        base = 2;
        s += 5;
    } else if (starts_with_word(s, "int")) {
        base = 4;
        s += 3;
    } else if (starts_with_word(s, "float")) {
        base = 4;
        s += 5;
    } else if (starts_with_word(s, "double")) {
        base = 8;
        s += 6;
    } else if (starts_with_word(s, "size_t")) {
        base = 8;
        s += 6;
    } else if (starts_with_word(s, "long")) {
        base = 8;
        s += 4;
        s = skip_ws(s);
        if (starts_with_word(s, "long")) {
            s += 4;
            s = skip_ws(s);
        }
        if (starts_with_word(s, "int")) s += 3;
    } else if (saw_unsigned) {
        base = 4;
    } else {
        return -1;
    }
    *ps = s;
    return base;
}

/* Add a lower bound for a simple member line. Bit-fields and nested types add nothing. */
static void accum_simple_members(const char *line, int *bytes, int *fields) {
    if (strchr(line, '(') || strchr(line, ':')) return;
    const char *s = skip_ws(line);
    if (*s == '\0' || *s == '}' || *s == '#') return;
    if (cperf_find_word(s, "struct") || cperf_find_word(s, "union") ||
        cperf_find_word(s, "enum"))
        return;
    int base = parse_base_width(&s);
    if (base < 0) return;
    int added_b = 0;
    int added_f = 0;
    for (;;) {
        s = skip_ws(s);
        int ptr = 0;
        while (*s == '*') {
            ptr = 1;
            s++;
            s = skip_ws(s);
        }
        if (!cperf_is_ident_start(*s)) break;
        while (cperf_is_ident(*s)) s++;
        s = skip_ws(s);
        int width = ptr ? 8 : base;
        if (*s == '[') {
            s++;
            s = skip_ws(s);
            int n = 0;
            int k = decimal_span(s, &n);
            if (!k) break;
            s += k;
            s = skip_ws(s);
            if (*s != ']') break;
            s++;
            if (width > 0 && n > 2000000000 / width) break;
            width *= n;
        }
        added_b += width;
        added_f++;
        s = skip_ws(s);
        if (*s == ',') {
            s++;
            continue;
        }
        break;
    }
    if (!added_f) return;
    *bytes += added_b;
    *fields += added_f;
}

static void capture_struct_name(const char *line, char *out, size_t outsz) {
    out[0] = '\0';
    const char *p = cperf_find_word(line, "struct");
    if (!p) return;
    p = skip_ws(p + 6);
    if (!cperf_is_ident_start(*p)) return;
    size_t n = 0;
    while (cperf_is_ident(p[n]) && n + 1 < outsz) {
        out[n] = p[n];
        n++;
    }
    out[n] = '\0';
}

static void remember_record(RecSize *tab, int *n, const char *name, int bytes, int fields) {
    if (!name || !name[0] || *n < 0) return;
    for (int i = 0; i < *n; i++) {
        if (strcmp(tab[i].name, name) == 0) {
            tab[i].bytes = bytes;
            tab[i].fields = fields;
            return;
        }
    }
    if (*n >= MAX_REC_SIZES) return;
    snprintf(tab[*n].name, sizeof(tab[*n].name), "%s", name);
    tab[*n].bytes = bytes;
    tab[*n].fields = fields;
    (*n)++;
}

static const RecSize *find_record(const RecSize *tab, int n, const char *name, size_t len) {
    for (int i = 0; i < n; i++) {
        if (strlen(tab[i].name) == len && strncmp(tab[i].name, name, len) == 0) return &tab[i];
    }
    return NULL;
}

static int is_param_slot(const char *line, const char *struct_kw) {
    const char *b = struct_kw;
    while (b > line) {
        b--;
        if (isspace((unsigned char)*b)) continue;
        if (cperf_is_ident(*b)) {
            const char *end = b + 1;
            while (b > line && cperf_is_ident(b[-1])) b--;
            size_t n = (size_t)(end - b);
            if ((n == 5 && strncmp(b, "const", 5) == 0) ||
                (n == 8 && strncmp(b, "volatile", 8) == 0))
                continue;
            return 0;
        }
        return *b == '(' || *b == ',';
    }
    return 0;
}

static int prev_opens_param(const char *prev) {
    if (!prev) return 0;
    size_t n = strlen(prev);
    while (n > 0 && isspace((unsigned char)prev[n - 1])) n--;
    if (n == 0) return 0;
    return prev[n - 1] == '(' || prev[n - 1] == ',';
}

static int line_has_large_byvalue(const char *line, const char *prev, const RecSize *tab,
                                 int ntab) {
    const char *p = line;
    while ((p = cperf_find_word(p, "struct")) != NULL) {
        const char *ns = skip_ws(p + 6);
        if (!cperf_is_ident_start(*ns)) {
            p += 6;
            continue;
        }
        const char *ne = ns;
        while (cperf_is_ident(*ne)) ne++;
        const RecSize *rec = find_record(tab, ntab, ns, (size_t)(ne - ns));
        const char *after = skip_ws(ne);
        if (!rec || rec->bytes < MIN_BYVALUE_BYTES || rec->fields < MIN_BYVALUE_FIELDS) {
            p = ne;
            continue;
        }
        if (*after == '*') {
            p = after;
            continue;
        }
        if (!cperf_is_ident_start(*after)) {
            p = ne;
            continue;
        }
        while (cperf_is_ident(*after)) after++;
        after = skip_ws(after);
        if (*after == '[') {
            p = after;
            continue;
        }
        if (!is_param_slot(line, p) && !prev_opens_param(prev)) {
            p = after;
            continue;
        }
        return 1;
    }
    return 0;
}


static int member_is_bitfield(const char *line) {
    const char *colon = strchr(line, ':');
    if (!colon || colon[1] == ':') return 0;
    const char *semi = strchr(line, ';');
    if (!semi || colon > semi) return 0;
    const char *w = skip_ws(colon + 1);
    return *w >= '0' && *w <= '9';
}

static int starts_with_word(const char *s, const char *w) {
    size_t n = strlen(w);
    if (strncmp(s, w, n) != 0) return 0;
    return !cperf_is_ident(s[n]);
}

static int name_is_flag(const char *name) {
    return strncmp(name, "is_", 3) == 0 || strncmp(name, "has_", 4) == 0 ||
           strncmp(name, "can_", 4) == 0;
}

/* Full-width bool, or an int whose name is a flag. Bit-fields return 0. */
static int wide_flag_member(const char *line) {
    if (member_is_bitfield(line)) return 0;
    const char *s = skip_ws(line);
    if (*s == '\0' || *s == '#' || *s == '/' || *s == '*') return 0;
    int is_bool = 0;
    if (starts_with_word(s, "_Bool")) {
        s += 5;
        is_bool = 1;
    } else if (starts_with_word(s, "bool")) {
        s += 4;
        is_bool = 1;
    } else if (starts_with_word(s, "unsigned")) {
        s = skip_ws(s + 8);
        if (starts_with_word(s, "int")) s = skip_ws(s + 3);
    } else if (starts_with_word(s, "signed")) {
        s = skip_ws(s + 6);
        if (starts_with_word(s, "int")) s = skip_ws(s + 3);
    } else if (starts_with_word(s, "int")) {
        s = skip_ws(s + 3);
    } else {
        return 0;
    }
    s = skip_ws(s);
    if (!cperf_is_ident_start(*s)) return 0;
    char name[64];
    size_t n = 0;
    while (cperf_is_ident(s[n]) && n + 1 < sizeof(name)) {
        name[n] = s[n];
        n++;
    }
    name[n] = '\0';
    if (!is_bool && !name_is_flag(name)) return 0;
    return *skip_ws(s + n) == ';';
}

static int has_named_call(const char *line, const char *const *names) {
    for (int i = 0; names[i]; i++) {
        const char *p = cperf_find_word(line, names[i]);
        if (!p) continue;
        p += strlen(names[i]);
        p = skip_ws(p);
        if (*p == '(') return 1;
    }
    return 0;
}

int scan_file(const char *path, FindingList *out, const char *scope) {
    int scope_all = !(scope && strcmp(scope, "loop") == 0);
    FILE *fp = fopen(path, "rb");
    if (!fp) return -1;

    int depth = 0;
    int loop_stack[MAX_STACK];
    int loop_sp = 0;
    int pending_loop = 0;
    char bind_names[32][64];
    int bind_n = 0;
    int bind_mark[MAX_STACK];
    char pending_names[8][64];
    int pending_n = 0;
    char current_func[MAX_FUNC] = "";
    int prev_type_only = 0;
    char prev_nonempty[MAX_PREV] = "";
    int ifdef_stack[MAX_STACK];
    int ifdef_sp = 0;
    int in_block = 0;
    int in_record = 0;
    int record_depth = 0;
    int flag_n = 0;
    int saw_bits = 0;
    int record_line = 0;
    RecSize rec_tab[MAX_REC_SIZES];
    int nrec = 0;
    int rec_bytes = 0;
    int rec_fields = 0;
    char rec_name[64];
    rec_name[0] = '\0';

    char raw[MAX_LINE];
    char line[MAX_LINE];
    int lineno = 0;

    while (fgets(raw, sizeof(raw), fp)) {
        lineno++;
        in_block = strip_comments_line(raw, line, sizeof(line), in_block);
        /* trim */
        char *stripped = (char *)skip_ws(line);
        char *end = stripped + strlen(stripped);
        while (end > stripped && isspace((unsigned char)end[-1])) {
            end--;
            *end = '\0';
        }
        if (!*stripped) continue;

        if (stripped[0] == '#') {
            update_ifdef_stack(ifdef_stack, &ifdef_sp, MAX_STACK, stripped);
            strncpy(prev_nonempty, stripped, sizeof(prev_nonempty) - 1);
            prev_nonempty[sizeof(prev_nonempty) - 1] = '\0';
            continue;
        }

        char fname[MAX_FUNC];
        if (looks_like_func_def(line, prev_type_only, fname, sizeof(fname))) {
            strncpy(current_func, fname, sizeof(current_func) - 1);
            current_func[sizeof(current_func) - 1] = '\0';
        }

        prev_type_only = is_type_only_line(stripped);

        int saw_loop = line_has_loop_kw(line);
        if (saw_loop) {
            pending_loop = 1;
            parse_for_binds(line, pending_names, &pending_n);
        }

        if (has_realloc_grow2(line)) {
            finding_list_push(out, "cp-realloc-grow-one", path, lineno,
                              "realloc grow looks like size+1; track capacity separately");
        }

        int single_body = 0;
        for (const char *ch = line; *ch; ch++) {
            if (*ch == '{') {
                depth++;
                if (pending_loop) {
                    if (loop_sp < MAX_STACK) {
                        bind_mark[loop_sp] = bind_n;
                        for (int bi = 0; bi < pending_n && bind_n < 32; bi++) {
                            snprintf(bind_names[bind_n], 64, "%s", pending_names[bi]);
                            bind_n++;
                        }
                        loop_stack[loop_sp++] = depth;
                    }
                    pending_loop = 0;
                    pending_n = 0;
                }
            } else if (*ch == '}') {
                if (loop_sp > 0 && depth == loop_stack[loop_sp - 1]) {
                    loop_sp--;
                    bind_n = bind_mark[loop_sp];
                }
                if (depth > 0) depth--;
                if (pending_loop) pending_loop = 0;
            }
        }

        /* brace-less empty for(...); */
        if (pending_loop && strstr(line, ");") && !strchr(line, '{')) {
            /* ) ; pattern */
            const char *rp = strrchr(line, ')');
            if (rp) {
                const char *q = skip_ws(rp + 1);
                if (*q == ';') pending_loop = 0;
            }
        }
        if (pending_loop && !strchr(line, '{') && strchr(line, ';')) {
            if (!saw_loop) {
                single_body = 1;
                pending_loop = 0;
            } else {
                /* for (...) stmt; on same line */
                const char *rp = strchr(line, ')');
                if (rp && strchr(rp, ';') && strchr(rp, ';') > rp) {
                    /* check something between ) and ; */
                    const char *q = skip_ws(rp + 1);
                    if (*q && *q != ';' && *q != '{') {
                        single_body = 1;
                        pending_loop = 0;
                    }
                }
            }
        }

        int active = scope_all || (loop_sp > 0) || single_body;
        int in_dump = ifdef_any(ifdef_stack, ifdef_sp);
        if (active && has_alloc_call(line) && !in_dump) {
            if (!has_return_alloc(line) && !is_doubling_realloc(line)) {
                finding_list_push(out, "cp-alloc-hot", path, lineno,
                                  "allocation; consider arena/pool or hoist — cost adds up even off a hot path");
            }
        }
        if (active && has_print_call(line)) {
            if (!should_skip_cp003(line, raw, prev_nonempty, current_func, in_dump)) {
                finding_list_push(out, "cp-printf-hot", path, lineno,
                                  "stdio print; buffer or remove — cost adds up even off a hot path");
            }
        }
        /* cp-strlen-in-cond: strlen in for/while condition (line-local; does not need loop_sp). */
        if (has_strlen_in_loop_cond(line) && !in_dump) {
            finding_list_push(out, "cp-strlen-in-cond", path, lineno,
                              "strlen in condition; hoist length to a local — cost adds up even off a hot path");
        }
        if (active && has_strcat_call(line) && !in_dump) {
            /* macro continuation — definition site, not a hot loop body */
            size_t rlen = strlen(raw);
            while (rlen > 0 && (raw[rlen - 1] == '\n' || raw[rlen - 1] == '\r' ||
                                isspace((unsigned char)raw[rlen - 1])))
                rlen--;
            if (!(rlen > 0 && raw[rlen - 1] == '\\')) {
                finding_list_push(out, "cp-strcat-hot", path, lineno,
                                  "strcat/strncat; track end pointer or use memcpy — cost adds up even off a hot path");
            }
        }
        if (active && !in_dump && has_named_call(line, k_buf_fmt_names)) {
            finding_list_push(out, "cp-sprintf-hot", path, lineno, k_msg_buf_fmt);
        }
        if (active && !in_dump && has_named_call(line, k_file_open_names) &&
            !named_call_uses_bind(line, k_file_open_names, bind_names, bind_n)) {
            finding_list_push(out, "cp-fopen-hot", path, lineno, k_msg_file_open);
        }
        if (active && !in_dump && has_named_call(line, k_clock_names)) {
            finding_list_push(out, "cp-gettime-hot", path, lineno, k_msg_clock);
        }
        if (active && !in_dump && has_named_call(line, k_regex_names) &&
            !named_call_uses_bind(line, k_regex_names, bind_names, bind_n)) {
            finding_list_push(out, "cp-regex-hot", path, lineno, k_msg_regex);
        }
        if (active && !in_dump && has_named_call(line, k_stack_names)) {
            finding_list_push(out, "cp-alloca-hot", path, lineno, k_msg_stack);
        }
        if (!in_record && cperf_find_word(line, "struct") && strchr(line, '{')) {
            in_record = 1;
            record_depth = depth;
            flag_n = 0;
            saw_bits = 0;
            record_line = lineno;
            rec_bytes = 0;
            rec_fields = 0;
            capture_struct_name(line, rec_name, sizeof(rec_name));
        } else if (in_record && depth >= record_depth) {
            if (member_is_bitfield(line)) saw_bits = 1;
            else if (wide_flag_member(line)) flag_n++;
            accum_simple_members(line, &rec_bytes, &rec_fields);
        }
        if (in_record && depth < record_depth) {
            if (flag_n >= 4 && !saw_bits && !in_dump) {
                finding_list_push(out, "cp-wide-bool-flags", path, record_line,
                                  "full-width boolean flags in one record; bit-fields or one mask pack them when many copies share a tight RAM budget");
            }
            remember_record(rec_tab, &nrec, rec_name, rec_bytes, rec_fields);
            in_record = 0;
        }
        if (!in_dump && line_has_large_byvalue(line, prev_nonempty, rec_tab, nrec)) {
            finding_list_push(out, "cp-struct-by-value", path, lineno, k_msg_byvalue);
        }

        strncpy(prev_nonempty, stripped, sizeof(prev_nonempty) - 1);
        prev_nonempty[sizeof(prev_nonempty) - 1] = '\0';
    }

    fclose(fp);
    return 0;
}
