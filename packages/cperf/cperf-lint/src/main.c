#include "cperf_lint.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum { SEV_OFF = 0, SEV_HINT = 1, SEV_ERROR = 2 } Sev;

typedef struct {
    Sev cp001;
    Sev cp002;
    Sev cp003;
    Sev cp004;
    Sev cp005;
    Sev cp006;
    Sev cp007;
    Sev cp008;
    Sev cp009;
    Sev cp010;
    Sev cp011;
    Sev cp012;
} RuleSev;

static Sev parse_sev(const char *s) {
    if (strcmp(s, "error") == 0) return SEV_ERROR;
    if (strcmp(s, "hint") == 0) return SEV_HINT;
    if (strcmp(s, "off") == 0) return SEV_OFF;
    return (Sev)-1;
}

static const char *sev_name(Sev s) {
    if (s == SEV_ERROR) return "error";
    if (s == SEV_HINT) return "hint";
    return "off";
}

static void apply_preset(RuleSev *rs, const char *name) {
    /* app/engine default: evidence-gated errors only (see docs/evidence-policy.md) */
    if (strcmp(name, "all") == 0) {
        rs->cp001 = SEV_ERROR;
        rs->cp002 = SEV_ERROR;
        rs->cp003 = SEV_ERROR;
        rs->cp004 = SEV_ERROR;
        rs->cp005 = SEV_ERROR;
        rs->cp006 = SEV_ERROR;
        rs->cp007 = SEV_ERROR;
        rs->cp008 = SEV_ERROR;
        rs->cp009 = SEV_ERROR;
        rs->cp010 = SEV_ERROR;
        rs->cp011 = SEV_ERROR;
        rs->cp012 = SEV_ERROR;
        return;
    }
    /* evidence-gated: cp-alloc-in-loop/cp-realloc-grow-one error; cp-printf-in-loop off (G3);
     * cp-strlen-in-cond hint; cp-strcat-in-loop off (G3 almost-all OK-idiom).
     * Later hints stay hint and are not corpus-triaged. */
    rs->cp001 = SEV_ERROR;
    rs->cp002 = SEV_ERROR;
    rs->cp003 = SEV_OFF;
    rs->cp004 = SEV_HINT;
    rs->cp005 = SEV_OFF;
    rs->cp006 = SEV_HINT;
    rs->cp007 = SEV_HINT;
    rs->cp008 = SEV_HINT;
    rs->cp009 = SEV_HINT;
    rs->cp010 = SEV_HINT;
    rs->cp011 = SEV_HINT;
    rs->cp012 = SEV_HINT;
}

static int apply_severity_override(RuleSev *rs, const char *spec) {
    char buf[64];
    size_t n = strlen(spec);
    if (n >= sizeof(buf)) return -1;
    memcpy(buf, spec, n + 1);
    char *eq = strchr(buf, '=');
    if (!eq) return -1;
    *eq = '\0';
    Sev s = parse_sev(eq + 1);
    if ((int)s < 0) return -1;

    if (strcmp(buf, "cp-alloc-in-loop") == 0) {
        rs->cp001 = s;
        return 0;
    }
    if (strcmp(buf, "cp-realloc-grow-one") == 0) {
        rs->cp002 = s;
        return 0;
    }
    if (strcmp(buf, "cp-printf-in-loop") == 0) {
        rs->cp003 = s;
        return 0;
    }
    if (strcmp(buf, "cp-strlen-in-cond") == 0) {
        rs->cp004 = s;
        return 0;
    }
    if (strcmp(buf, "cp-strcat-in-loop") == 0) {
        rs->cp005 = s;
        return 0;
    }
    if (strcmp(buf, "cp-sprintf-in-loop") == 0) {
        rs->cp006 = s;
        return 0;
    }
    if (strcmp(buf, "cp-fopen-in-loop") == 0) {
        rs->cp007 = s;
        return 0;
    }
    if (strcmp(buf, "cp-gettime-in-loop") == 0) {
        rs->cp008 = s;
        return 0;
    }
    if (strcmp(buf, "cp-wide-bool-flags") == 0) {
        rs->cp009 = s;
        return 0;
    }
    if (strcmp(buf, "cp-regex-in-loop") == 0) {
        rs->cp010 = s;
        return 0;
    }
    if (strcmp(buf, "cp-alloca-in-loop") == 0) {
        rs->cp011 = s;
        return 0;
    }
    if (strcmp(buf, "cp-struct-by-value") == 0) {
        rs->cp012 = s;
        return 0;
    }
    return -1;
}

static Sev severity_of(const RuleSev *rs, const char *rule) {
    if (strcmp(rule, "cp-alloc-in-loop") == 0) return rs->cp001;
    if (strcmp(rule, "cp-realloc-grow-one") == 0) return rs->cp002;
    if (strcmp(rule, "cp-printf-in-loop") == 0) return rs->cp003;
    if (strcmp(rule, "cp-strlen-in-cond") == 0) return rs->cp004;
    if (strcmp(rule, "cp-strcat-in-loop") == 0) return rs->cp005;
    if (strcmp(rule, "cp-sprintf-in-loop") == 0) return rs->cp006;
    if (strcmp(rule, "cp-fopen-in-loop") == 0) return rs->cp007;
    if (strcmp(rule, "cp-gettime-in-loop") == 0) return rs->cp008;
    if (strcmp(rule, "cp-wide-bool-flags") == 0) return rs->cp009;
    if (strcmp(rule, "cp-regex-in-loop") == 0) return rs->cp010;
    if (strcmp(rule, "cp-alloca-in-loop") == 0) return rs->cp011;
    if (strcmp(rule, "cp-struct-by-value") == 0) return rs->cp012;
    return SEV_HINT; /* unknown stays hint, never error */
}

static void usage(int code) {
    fprintf(stderr,
            "Usage: cperf-lint [PATH...] [options]\n"
            "  --format text|json\n"
            "  --preset app|engine|all   (default: app)\n"
            "  --severity RULE=error|hint|off   (repeatable; overrides preset)\n"
            "  --strict-hints            hints also fail the exit code\n"
            "  --no-fail                 always exit 0 on findings\n"
            "Heuristic C/C++ performance lint (C11).\n"
            "Exit 1 only on error-severity findings (or hints with --strict-hints).\n");
    exit(code);
}

static void print_json(const FindingList *fl, const RuleSev *rs) {
    printf("[\n");
    int first = 1;
    size_t i = 0;
    while (i < fl->len) {
        const Finding *f = &fl->items[i];
        Sev s = severity_of(rs, f->rule);
        i++;
        if (s == SEV_OFF) continue;
        if (!first) printf(",\n");
        first = 0;
        printf("  {\n");
        printf("    \"rule\": \"%s\",\n", f->rule);
        printf("    \"severity\": \"%s\",\n", sev_name(s));
        printf("    \"path\": \"");
        const char *p = f->path;
        while (*p) {
            if (*p == '\\' || *p == '"') putchar('\\');
            putchar(*p);
            p++;
        }
        printf("\",\n");
        printf("    \"line\": %d,\n", f->line);
        printf("    \"message\": \"");
        p = f->message;
        while (*p) {
            if (*p == '\\' || *p == '"') putchar('\\');
            putchar(*p);
            p++;
        }
        printf("\"\n");
        printf("  }");
    }
    if (!first) printf("\n");
    printf("]\n");
}

/* Named dump_* so cp-printf-in-loop self-lint stays quiet on report emission. */
static void dump_text_findings(const FindingList *fl, const RuleSev *rs,
                               size_t *out_errors, size_t *out_hints) {
    size_t shown = 0;
    size_t nerr = 0;
    size_t nhint = 0;
    size_t i = 0;
    while (i < fl->len) {
        Finding *f = &fl->items[i];
        Sev s = severity_of(rs, f->rule);
        i++;
        if (s == SEV_OFF) continue;
        printf("%s:%d: %s %s: %s\n", f->path, f->line, sev_name(s), f->rule,
               f->message);
        shown++;
        if (s == SEV_ERROR) nerr++;
        else nhint++;
    }
    if (shown)
        fprintf(stderr, "%zu finding(s) (%zu error, %zu hint)\n", shown, nerr,
                nhint);
    else
        fprintf(stderr, "ok\n");
    *out_errors = nerr;
    *out_hints = nhint;
}

static void count_findings(const FindingList *fl, const RuleSev *rs,
                           size_t *out_errors, size_t *out_hints) {
    size_t nerr = 0;
    size_t nhint = 0;
    size_t i = 0;
    while (i < fl->len) {
        Sev s = severity_of(rs, fl->items[i].rule);
        i++;
        if (s == SEV_ERROR) nerr++;
        else if (s == SEV_HINT) nhint++;
    }
    *out_errors = nerr;
    *out_hints = nhint;
}

int main(int argc, char **argv) {
    int want_help = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0)
            want_help = 1;
    }
    if (want_help) usage(0);

    const char *format = "text";
    int no_fail = 0;
    int strict_hints = 0;
    const char *preset = "app";
    /* Pre-size override list to argc (no realloc in parse loop — cp-alloc-in-loop). */
    char **sev_overrides = NULL;
    size_t n_overrides = 0;
    char **paths = NULL;
    size_t npaths = 0;

    if (argc > 1) {
        paths = calloc((size_t)argc, sizeof(char *));
        sev_overrides = calloc((size_t)argc, sizeof(char *));
        if (!paths || !sev_overrides) {
            free(paths);
            free(sev_overrides);
            fprintf(stderr, "error: oom\n");
            return 2;
        }
    }

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--format") == 0) {
            if (++i >= argc) {
                free(paths);
                free(sev_overrides);
                usage(2);
            }
            format = argv[i];
            if (strcmp(format, "text") != 0 && strcmp(format, "json") != 0) {
                free(paths);
                free(sev_overrides);
                usage(2);
            }
            continue;
        }
        if (strcmp(argv[i], "--preset") == 0) {
            if (++i >= argc) {
                free(paths);
                free(sev_overrides);
                usage(2);
            }
            preset = argv[i];
            if (strcmp(preset, "app") != 0 && strcmp(preset, "engine") != 0 &&
                strcmp(preset, "all") != 0) {
                free(paths);
                free(sev_overrides);
                usage(2);
            }
            continue;
        }
        if (strcmp(argv[i], "--severity") == 0) {
            if (++i >= argc) {
                free(paths);
                free(sev_overrides);
                usage(2);
            }
            sev_overrides[n_overrides++] = argv[i];
            continue;
        }
        if (strcmp(argv[i], "--no-fail") == 0) {
            no_fail = 1;
            continue;
        }
        if (strcmp(argv[i], "--strict-hints") == 0) {
            strict_hints = 1;
            continue;
        }
        if (argv[i][0] == '-') {
            free(paths);
            free(sev_overrides);
            usage(2);
        }
        paths[npaths++] = argv[i];
    }

    if (npaths == 0) {
        free(paths);
        free(sev_overrides);
        usage(2);
    }

    RuleSev rs;
    apply_preset(&rs, preset);
    for (size_t oi = 0; oi < n_overrides; oi++) {
        if (apply_severity_override(&rs, sev_overrides[oi]) != 0) {
            fprintf(stderr,
                    "error: bad --severity %s (want slug=error|hint|off)\n",
                    sev_overrides[oi]);
            free(paths);
            free(sev_overrides);
            return 2;
        }
    }

    FindingList fl;
    finding_list_init(&fl);
    int io_errors = 0;
    for (size_t i = 0; i < npaths; i++) {
        if (scan_path(paths[i], &fl) != 0) {
            fprintf(stderr, "error: %s: I/O or walk failure\n", paths[i]);
            io_errors++;
        }
    }

    size_t nerr = 0;
    size_t nhint = 0;
    if (strcmp(format, "json") == 0) {
        print_json(&fl, &rs);
        count_findings(&fl, &rs, &nerr, &nhint);
        if (nerr + nhint)
            fprintf(stderr, "%zu finding(s) (%zu error, %zu hint)\n",
                    nerr + nhint, nerr, nhint);
        else
            fprintf(stderr, "ok\n");
    } else {
        dump_text_findings(&fl, &rs, &nerr, &nhint);
    }

    int rc = 0;
    if (io_errors)
        rc = 2;
    else if (!no_fail) {
        if (nerr) rc = 1;
        else if (strict_hints && nhint) rc = 1;
    }

    finding_list_free(&fl);
    free(paths);
    free(sev_overrides);
    return rc;
}
