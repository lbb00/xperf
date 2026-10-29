package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/xperf/goperf-lint/internal/scan"
)

const (
	sevOff   = 0
	sevHint  = 1
	sevError = 2
)

func parseSev(s string) int {
	switch s {
	case "error":
		return sevError
	case "hint":
		return sevHint
	case "off":
		return sevOff
	}
	return -1
}

func sevName(s int) string {
	switch s {
	case sevError:
		return "error"
	case sevHint:
		return "hint"
	default:
		return "off"
	}
}

func defaultSev() map[string]int {
	return map[string]int{
		"gp-make-hot":           sevOff,  // G3: almost-all OK-idiom on go-src
		"gp-string-plus-hot":    sevOff,  // G3: assert/stdlib assemble OK-idiom
		"gp-fmt-hot":            sevOff,  // G3: debug/codegen fmt
		"gp-append-nil-slice":       sevHint, // empty slice + append in size-hinted loop
		"gp-defer-hot":          sevHint, // defer stacking / hot use
		"gp-regexp-compile-hot": sevHint, // not corpus-triaged
		"gp-json-marshal-hot":   sevHint,
		"gp-reflect-hot":        sevHint,
		"gp-os-open-hot":        sevHint,
		"gp-time-now-hot":       sevHint,
	}
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		usage(2)
	}
	rs := defaultSev()
	format := "text"
	strictHints := false
	noFail := false
	scope := "all"
	paths := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "-h" || a == "--help":
			usage(0)
		case a == "--format":
			i++
			if i >= len(args) {
				usage(2)
			}
			format = args[i]
		case strings.HasPrefix(a, "--format="):
			format = strings.TrimPrefix(a, "--format=")
		case a == "--severity":
			i++
			if i >= len(args) || !applySev(rs, args[i]) {
				usage(2)
			}
		case strings.HasPrefix(a, "--severity="):
			if !applySev(rs, strings.TrimPrefix(a, "--severity=")) {
				usage(2)
			}
		case a == "--strict-hints":
			strictHints = true
		case a == "--no-fail":
			noFail = true
		case a == "--scope":
			i++
			if i >= len(args) {
				usage(2)
			}
			scope = args[i]
			if scope != "all" && scope != "loop" {
				usage(2)
			}
		case strings.HasPrefix(a, "--scope="):
			scope = strings.TrimPrefix(a, "--scope=")
			if scope != "all" && scope != "loop" {
				usage(2)
			}
		case strings.HasPrefix(a, "-"):
			usage(2)
		default:
			paths = append(paths, a)
		}
	}
	if len(paths) == 0 {
		usage(2)
	}
	findings := make([]scan.Finding, 0, len(paths)*4)
	for _, p := range paths {
		fs, err := scan.ScanPath(p, scope)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
		findings = append(findings, fs...)
	}
	nerr, nhint := emit(findings, rs, format)
	if noFail {
		os.Exit(0)
	}
	if nerr > 0 || (strictHints && nhint > 0) {
		os.Exit(1)
	}
}

func applySev(rs map[string]int, spec string) bool {
	eq := strings.IndexByte(spec, '=')
	if eq < 0 {
		return false
	}
	rule := spec[:eq]
	s := parseSev(spec[eq+1:])
	if s < 0 {
		return false
	}
	if _, ok := rs[rule]; !ok {
		return false
	}
	rs[rule] = s
	return true
}

func emit(findings []scan.Finding, rs map[string]int, format string) (nerr, nhint int) {
	type row struct {
		Rule     string `json:"rule"`
		Severity string `json:"severity"`
		Path     string `json:"path"`
		Line     int    `json:"line"`
		Message  string `json:"message"`
	}
	rows := make([]row, 0, len(findings))
	lines := make([]string, 0, len(findings))
	for _, f := range findings {
		s, ok := rs[f.Rule]
		if !ok {
			s = sevHint
		}
		if s == sevOff {
			continue
		}
		if s == sevError {
			nerr++
		} else {
			nhint++
		}
		if format == "json" {
			rows = append(rows, row{f.Rule, sevName(s), f.Path, f.Line, f.Message})
		} else {
			// Prefer Builder over fmt in this loop so gp-fmt-hot self-dogfood stays clean.
			var b strings.Builder
			b.WriteString(f.Path)
			b.WriteByte(':')
			b.WriteString(strconv.Itoa(f.Line))
			b.WriteString(": ")
			b.WriteString(sevName(s))
			b.WriteByte(' ')
			b.WriteString(f.Rule)
			b.WriteString(": ")
			b.WriteString(f.Message)
			lines = append(lines, b.String())
		}
	}
	if format == "json" {
		enc := json.NewEncoder(os.Stdout)
		_ = enc.Encode(rows)
	} else {
		if len(lines) > 0 {
			fmt.Println(strings.Join(lines, "\n"))
		}
		shown := nerr + nhint
		if shown > 0 {
			fmt.Fprintf(os.Stderr, "%d finding(s) (%d error, %d hint)\n", shown, nerr, nhint)
		} else {
			fmt.Fprintln(os.Stderr, "ok")
		}
	}
	return
}

func usage(code int) {
	fmt.Fprintln(os.Stderr, `Usage: goperf-lint PATH... [options]
  --format text|json
  --severity RULE=error|hint|off
  --strict-hints
  --no-fail`)
	os.Exit(code)
}
