package scan

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type Finding struct {
	Rule    string `json:"rule"`
	Path    string `json:"path"`
	Line    int    `json:"line"`
	Message string `json:"message"`
}

type binding struct {
	name  string
	line  int
	depth int
}

var (
	reLoop          = regexp.MustCompile(`\b(for)\b`)
	reMake          = regexp.MustCompile(`\b(make|new)\s*\(`)
	reMakeChan      = regexp.MustCompile(`\bmake\s*\(\s*(<-)?chan\b`)
	reStrAdd        = regexp.MustCompile(`\w+\s*\+=\s*`)
	reFmt           = regexp.MustCompile(`\bfmt\.(Sprintf|Printf|Fprintf|Errorf)\s*\(`)
	reDefer         = regexp.MustCompile(`\bdefer\s`)
	reFunc          = regexp.MustCompile(`\bfunc\b`)
	reAppend        = regexp.MustCompile(`\b([A-Za-z_][\w]*)\s*=\s*append\s*\(\s*([A-Za-z_][\w]*)\s*,`)
	reVarSlice      = regexp.MustCompile(`\bvar\s+([A-Za-z_][\w]*)\s+\[\]`)
	reShortNil      = regexp.MustCompile(`\b([A-Za-z_][\w]*)\s*:?=\s*\[\][\w\.\[\]]*\{\s*\}`)
	reShortNil2     = regexp.MustCompile(`\b([A-Za-z_][\w]*)\s*:?=\s*\(\s*\[\][\w\.\[\]]+\)\s*\(\s*nil\s*\)`)
	reMakeCap       = regexp.MustCompile(`\bmake\s*\(\s*\[\][^,]+,\s*0\s*,`)
	reRegexpCompile = regexp.MustCompile(`\bregexp\.(MustCompilePOSIX|MustCompile|CompilePOSIX|Compile)\s*\(`)
	reJSONMarshal   = regexp.MustCompile(`\bjson\.(MarshalIndent|Marshal|Unmarshal)\s*\(`)
	reReflect       = regexp.MustCompile(`(\.(FieldByName|MethodByName)\s*\()|(\breflect\.New\s*\()`)
	reOsOpen        = regexp.MustCompile(`\bos\.Open\s*\(`)
	reTimeNow       = regexp.MustCompile(`\btime\.Now\s*\(`)
	reForHead       = regexp.MustCompile(`\bfor\s+([^{]+)`)
	reRegexpArg     = regexp.MustCompile(`\bregexp\.(?:MustCompilePOSIX|MustCompile|CompilePOSIX|Compile)\s*\(([^)\n]*)`)
	reJSONArg       = regexp.MustCompile(`\bjson\.(?:MarshalIndent|Marshal|Unmarshal)\s*\(([^)\n]*)`)
	reOsOpenArg     = regexp.MustCompile(`\bos\.Open\s*\(([^)\n]*)`)
	msg001          = "make/new; reuse buffers when profiles show pressure — cost adds up even off a hot path"
	msg002          = "string +=; prefer strings.Builder — cost adds up even off a hot path"
	msg003          = "fmt.*printf; gate debug or use cheaper writers — cost adds up even off a hot path"
	msg004          = "empty slice grown with append in size-hinted loop; prefer make([]T, 0, n)"
	msg005          = "defer; calls accumulate until function returns — cost adds up even off a hot path"
	msg006          = "regexp.Compile; compile outside only when this pattern stays the same — cost adds up even off a hot path"
	msg007          = "json.Marshal/Unmarshal; hoist only when this value stays the same — cost adds up even off a hot path"
	msg008          = "reflect name lookup or reflect.New; resolve it outside — cost adds up even off a hot path"
	msg009          = "file open; open once when the path stays the same — cost adds up even off a hot path"
	msg010          = "clock sample; hoist only when this iteration does not need a fresh time — cost adds up even off a hot path"
)

func isGo(path string) bool {
	return strings.HasSuffix(path, ".go") && !strings.HasSuffix(path, "_test.go")
}

func skipDir(name string) bool {
	switch name {
	case ".git", "vendor", "testdata", "node_modules", "fixtures", "_gen", "_codegen":
		return true
	// Go toolchain command trees are cold relative to library hot paths.
	case "cmd":
		return true
	}
	return false
}

func skipFile(name string) bool {
	if strings.HasPrefix(name, "mk") && strings.HasSuffix(name, ".go") {
		return true
	}
	// Code generators.
	if name == "generate.go" {
		return true
	}
	return false
}

func loopHasSizeHint(code string) bool {
	t := strings.TrimSpace(code)
	if strings.Contains(t, " range ") || strings.HasSuffix(t, " range") || strings.Contains(t, "\trange ") {
		return true
	}
	// for i := 0; i < n; i++  /  for i := 0; i < len(x); i++
	if strings.Contains(t, ";") && (strings.Contains(t, "<") || strings.Contains(t, "len(")) {
		return true
	}
	if strings.Contains(t, "len(") {
		return true
	}
	return false
}

func ScanFile(path string, scope string) ([]Finding, error) {
	scopeMode := "all"
	if scope == "loop" {
		scopeMode = "loop"
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var out []Finding
	depth := 0
	inLoop := 0
	loopHint := false
	loopNest := 0 // nested-func count when loop opened
	nestedFuncs := 0
	pendingFunc := false
	var funcStack []int // depth at which each nested func body started
	var binds []binding
	var loopNames []string
	fired004 := map[string]bool{}
	sc := bufio.NewScanner(f)
	buf := make([]byte, 0, 64*1024)
	sc.Buffer(buf, 1024*1024)
	lineNo := 0
	for sc.Scan() {
		lineNo++
		raw := sc.Text()
		code := stripLineComment(raw)
		match := codeForMatch(code)
		opens := strings.Count(code, "{")
		closes := strings.Count(code, "}")

		if m := reVarSlice.FindStringSubmatch(match); m != nil {
			binds = append(binds, binding{m[1], lineNo, depth})
		}
		if m := reShortNil.FindStringSubmatch(match); m != nil {
			binds = append(binds, binding{m[1], lineNo, depth})
		}
		if m := reShortNil2.FindStringSubmatch(match); m != nil {
			binds = append(binds, binding{m[1], lineNo, depth})
		}
		// Drop stale bindings (different function / far above).
		kept := binds[:0]
		for _, b := range binds {
			if lineNo-b.line <= 80 && b.depth <= depth+1 {
				kept = append(kept, b)
			}
		}
		binds = kept

		if reLoop.MatchString(match) {
			inLoop = depth + 1
			loopHint = loopHasSizeHint(match)
			loopNest = nestedFuncs
			loopNames = append(loopNames, forBindNames(match)...)
		}
		matchHere := scopeMode == "all" || (inLoop > 0 && depth >= inLoop)
		if matchHere {
			if reMake.MatchString(match) && !reMakeChan.MatchString(match) {
				out = append(out, Finding{Rule: "gp-make-hot", Path: path, Line: lineNo, Message: msg001})
			}
			if reStrAdd.MatchString(match) && looksStringPlus(code) && !isTinyStringPlus(code) {
				out = append(out, Finding{Rule: "gp-string-plus-hot", Path: path, Line: lineNo, Message: msg002})
			}
			if reFmt.MatchString(match) {
				out = append(out, Finding{Rule: "gp-fmt-hot", Path: path, Line: lineNo, Message: msg003})
			}
			// gp-defer-hot: only when defer is in the same function as the loop (not a nested func/closure).
			if reDefer.MatchString(match) && nestedFuncs == loopNest {
				out = append(out, Finding{Rule: "gp-defer-hot", Path: path, Line: lineNo, Message: msg005})
			}
			if reRegexpCompile.MatchString(match) && !callArgUses(match, reRegexpArg, loopNames) {
				out = append(out, Finding{Rule: "gp-regexp-compile-hot", Path: path, Line: lineNo, Message: msg006})
			}
			if reJSONMarshal.MatchString(match) && !callArgUses(match, reJSONArg, loopNames) {
				out = append(out, Finding{Rule: "gp-json-marshal-hot", Path: path, Line: lineNo, Message: msg007})
			}
			if reReflect.MatchString(match) {
				out = append(out, Finding{Rule: "gp-reflect-hot", Path: path, Line: lineNo, Message: msg008})
			}
			if reOsOpen.MatchString(match) && !callArgUses(match, reOsOpenArg, loopNames) {
				out = append(out, Finding{Rule: "gp-os-open-hot", Path: path, Line: lineNo, Message: msg009})
			}
			if reTimeNow.MatchString(match) {
				out = append(out, Finding{Rule: "gp-time-now-hot", Path: path, Line: lineNo, Message: msg010})
			}
			if loopHint {
				if am := reAppend.FindStringSubmatch(match); am != nil && am[1] == am[2] {
					varName := am[1]
					if !fired004[varName] {
						hasEmpty := false
						for _, b := range binds {
							if b.name == varName && b.depth < inLoop+2 {
								hasEmpty = true
								break
							}
						}
						// Cap already reserved?
						hasCap := reMakeCap.MatchString(match)
						if !hasCap {
							// Look back a few lines in binds window — approximate via
							// rejecting if same line already has make(,0,.
							for _, b := range binds {
								if b.name == varName {
									_ = b
								}
							}
						}
						if hasEmpty && !hasCap {
							fired004[varName] = true
							out = append(out, Finding{Rule: "gp-append-nil-slice", Path: path, Line: lineNo, Message: msg004})
						}
					}
				}
			}
		}
		// If we see make([]T, 0, n) assigned to a bind, drop that bind (reserved).
		if reMakeCap.MatchString(match) {
			for i := range binds {
				if strings.Contains(code, binds[i].name) {
					binds[i].name = "" // invalidate
				}
			}
			filtered := binds[:0]
			for _, b := range binds {
				if b.name != "" {
					filtered = append(filtered, b)
				}
			}
			binds = filtered
		}

		if reFunc.MatchString(match) {
			pendingFunc = true
		}
		// Enter nested func on first { while pending.
		entered := 0
		if pendingFunc && opens > 0 {
			entered = 1
			pendingFunc = false
			nestedFuncs++
			funcStack = append(funcStack, depth+1)
		}

		depth += opens - closes
		if depth < 0 {
			depth = 0
		}
		// Pop nested funcs closed this line.
		for len(funcStack) > 0 && depth < funcStack[len(funcStack)-1] {
			funcStack = funcStack[:len(funcStack)-1]
			if nestedFuncs > 0 {
				nestedFuncs--
			}
		}
		_ = entered
		if inLoop > 0 && depth < inLoop {
			inLoop = 0
			loopHint = false
			loopNest = 0
			fired004 = map[string]bool{}
		}
	}
	return out, sc.Err()
}

func isTinyStringPlus(code string) bool {
	code = strings.TrimSpace(code)
	i := strings.Index(code, "+=")
	if i < 0 {
		return false
	}
	rhs := strings.TrimSpace(code[i+2:])
	if len(rhs) < 2 {
		return false
	}
	q := rhs[0]
	if q != '"' && q != '`' {
		return false
	}
	end := 1
	for end < len(rhs) {
		c := rhs[end]
		if c == '\\' && q == '"' {
			end += 2
			continue
		}
		if c == q {
			rest := strings.TrimSpace(rhs[end+1:])
			return rest == "" && end-1 <= 6
		}
		end++
	}
	return false
}

func looksStringPlus(code string) bool {
	return strings.Contains(code, "\"") || strings.Contains(code, "`") || strings.Contains(code, "string(")
}

// codeForMatch blanks string/rune literals so keywords inside strings do not fire.
func codeForMatch(s string) string {
	b := make([]byte, len(s))
	inStr := byte(0)
	for i := 0; i < len(s); i++ {
		c := s[i]
		if inStr != 0 {
			b[i] = ' '
			if c == '\\' && inStr != '`' {
				if i+1 < len(s) {
					b[i+1] = ' '
					i++
				}
				continue
			}
			if c == inStr {
				inStr = 0
			}
			continue
		}
		if c == '"' || c == '\'' || c == '`' {
			inStr = c
			b[i] = ' '
			continue
		}
		b[i] = c
	}
	return string(b)
}

func stripLineComment(s string) string {
	inStr := byte(0)
	for i := 0; i < len(s); i++ {
		c := s[i]
		if inStr != 0 {
			if c == '\\' && inStr != '`' {
				i++
				continue
			}
			if c == inStr {
				inStr = 0
			}
			continue
		}
		if c == '"' || c == '\'' || c == '`' {
			inStr = c
			continue
		}
		if c == '/' && i+1 < len(s) && s[i+1] == '/' {
			return s[:i]
		}
	}
	return s
}

func ScanPath(root string, scope string) ([]Finding, error) {
	info, err := os.Stat(root)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		if isGo(root) {
			return ScanFile(root, scope)
		}
		return nil, nil
	}
	var all []Finding
	err = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			if skipDir(info.Name()) {
				return filepath.SkipDir
			}
			return nil
		}
		if !isGo(path) || skipFile(info.Name()) {
			return nil
		}
		fs, err := ScanFile(path, scope)
		if err != nil {
			return err
		}
		all = append(all, fs...)
		return nil
	})
	return all, err
}

func forBindNames(match string) []string {
	m := reForHead.FindStringSubmatch(match)
	if m == nil {
		return nil
	}
	head := m[1]
	var left string
	if i := strings.Index(head, ":="); i >= 0 {
		left = head[:i]
	} else if i := strings.Index(head, "="); i >= 0 {
		left = head[:i]
	} else {
		return nil
	}
	names := make([]string, 0, 8)
	for _, part := range strings.Split(left, ",") {
		part = strings.TrimSpace(part)
		if part == "" || part == "_" || !identToken(part) {
			continue
		}
		names = append(names, part)
	}
	return names
}

func identToken(s string) bool {
	if s == "" {
		return false
	}
	for i := 0; i < len(s); i++ {
		if !identChar(s[i]) {
			return false
		}
	}
	return true
}

func identChar(c byte) bool {
	return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

func callArgUses(match string, re *regexp.Regexp, names []string) bool {
	if len(names) == 0 {
		return false
	}
	m := re.FindStringSubmatch(match)
	if m == nil {
		return false
	}
	args := m[1]
	for _, name := range names {
		if identIn(args, name) {
			return true
		}
	}
	return false
}

func identIn(s, name string) bool {
	if name == "" {
		return false
	}
	for i := 0; i+len(name) <= len(s); {
		j := strings.Index(s[i:], name)
		if j < 0 {
			return false
		}
		j += i
		before := j == 0 || !identChar(s[j-1])
		after := j+len(name) == len(s) || !identChar(s[j+len(name)])
		if before && after {
			return true
		}
		i = j + 1
	}
	return false
}
