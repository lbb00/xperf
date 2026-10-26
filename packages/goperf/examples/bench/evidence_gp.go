// Evidence microbench for gp-make-in-loop–gp-defer-in-loop → packages/goperf/evidence/GP*.jsonl
// go run evidence_gp.go
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"
)

const warm = 3
const rounds = 9

func median(xs []float64) float64 {
	a := append([]float64(nil), xs...)
	sort.Float64s(a)
	n := len(a)
	if n == 0 {
		return 0
	}
	if n%2 == 1 {
		return a[n/2]
	}
	return 0.5 * (a[n/2-1] + a[n/2])
}

func timeMany(fn func() int) float64 {
	for i := 0; i < warm; i++ {
		_ = fn()
	}
	samples := make([]float64, rounds)
	sink := 0
	for r := 0; r < rounds; r++ {
		t0 := time.Now()
		sink += fn()
		samples[r] = float64(time.Since(t0).Nanoseconds()) / 1e6
	}
	if sink == -1<<31 {
		panic("sink")
	}
	return median(samples)
}

func envInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func isoTS() string {
	return time.Now().UTC().Format("2006-01-02T15:04:05Z")
}

type line struct {
	rule, caseName, role string
	med                  float64
	ops                  int
	ratio                float64
}

func main() {
	outDir := os.Getenv("EVIDENCE_DIR")
	if outDir == "" {
		outDir = filepath.Join(filepath.Dir(os.Args[0]), "..", "..", "evidence")
		// when go run, Args[0] is in temp; resolve via this source layout
		wd, _ := os.Getwd()
		outDir = filepath.Join(wd, "..", "..", "evidence")
		if v := os.Getenv("EVIDENCE_DIR"); v != "" {
			outDir = v
		}
	}
	_ = os.MkdirAll(outDir, 0o755)

	goVer := runtime.Version()
	ts := isoTS()
	var all []line

	emit := func(rule, caseName, role string, med float64, ops int, ratio float64) {
		all = append(all, line{rule, caseName, role, med, ops, ratio})
		fmt.Fprintf(os.Stderr, "  %s %s %s median=%.3f ms ops=%d ratio=%.3f\n", rule, role, caseName, med, ops, ratio)
	}

	// --- gp-make-in-loop: make([]byte, 64) each iter vs reuse ---
	n1 := envInt("GP001_N", 200000)
	fmt.Fprintf(os.Stderr, "gp-make-in-loop make-in-loop n=%d\n", n1)
	med1a := timeMany(func() int {
		buf := make([]byte, 64)
		s := 0
		for i := 0; i < n1; i++ {
			buf[0] = byte(i)
			s += int(buf[0])
		}
		return s
	})
	med1b := timeMany(func() int {
		s := 0
		var out [][]byte
		for i := 0; i < n1; i++ {
			b := make([]byte, 64)
			b[0] = byte(i)
			out = append(out, b)
			s += int(b[0])
		}
		return s + len(out)
	})
	emit("gp-make-in-loop", "reuse_buf", "after", med1a, n1, 1)
	emit("gp-make-in-loop", "make_each_iter", "before", med1b, n1, med1b/max(med1a, 1e-9))

	// Pair B: fixture-shaped fill — make each + append vs presize one slice
	n1b := envInt("GP001_N_FILL", 50000)
	med1fa := timeMany(func() int {
		b := make([]byte, 0, n1b*64)
		for i := 0; i < n1b; i++ {
			b = append(b, make([]byte, 64)...)
			b[len(b)-64] = byte(i)
		}
		return len(b)
	})
	// better after: single alloc + index fill
	med1fa2 := timeMany(func() int {
		b := make([]byte, n1b*64)
		for i := 0; i < n1b; i++ {
			b[i*64] = byte(i)
		}
		return len(b)
	})
	med1fb := timeMany(func() int {
		var out [][]byte
		for i := 0; i < n1b; i++ {
			b := make([]byte, 64)
			b[0] = byte(i)
			out = append(out, b)
		}
		return len(out)
	})
	_ = med1fa
	emit("gp-make-in-loop", "single_slice_fill", "after", med1fa2, n1b, 1)
	emit("gp-make-in-loop", "make_append_slices", "before", med1fb, n1b, med1fb/max(med1fa2, 1e-9))

	// --- gp-string-plus-in-loop: string += vs Builder ---
	n2 := envInt("GP002_N", 50000)
	parts := make([]string, n2)
	for i := range parts {
		parts[i] = "x"
	}
	fmt.Fprintf(os.Stderr, "gp-string-plus-in-loop string-plus n=%d\n", n2)
	med2a := timeMany(func() int {
		var b strings.Builder
		b.Grow(n2)
		for _, p := range parts {
			b.WriteString(p)
		}
		return len(b.String())
	})
	med2b := timeMany(func() int {
		s := ""
		for _, p := range parts {
			s += p
		}
		return len(s)
	})
	emit("gp-string-plus-in-loop", "strings_builder", "after", med2a, n2, 1)
	emit("gp-string-plus-in-loop", "string_plus", "before", med2b, n2, med2b/max(med2a, 1e-9))

	n2s := envInt("GP002_N_SMALL", 100)
	partsS := parts[:n2s]
	med2sa := timeMany(func() int {
		var b strings.Builder
		for _, p := range partsS {
			b.WriteString(p)
		}
		return len(b.String())
	})
	med2sb := timeMany(func() int {
		s := ""
		for _, p := range partsS {
			s += p
		}
		return len(s)
	})
	emit("gp-string-plus-in-loop", "small_builder", "after", med2sa, n2s, 1)
	emit("gp-string-plus-in-loop", "small_string_plus", "before", med2sb, n2s, med2sb/max(med2sa, 1e-9))

	// --- gp-fmt-in-loop: fmt.Sprintf in loop vs strconv ---
	n3 := envInt("GP003_N", 100000)
	fmt.Fprintf(os.Stderr, "gp-fmt-in-loop fmt-loop n=%d\n", n3)
	med3a := timeMany(func() int {
		out := make([]string, 0, n3)
		for i := 0; i < n3; i++ {
			out = append(out, strconv.Itoa(i))
		}
		return len(out)
	})
	med3b := timeMany(func() int {
		out := make([]string, 0, n3)
		for i := 0; i < n3; i++ {
			out = append(out, fmt.Sprintf("id=%d", i))
		}
		return len(out)
	})
	// fairer: same format shape with Builder
	med3a2 := timeMany(func() int {
		out := make([]string, 0, n3)
		var b strings.Builder
		for i := 0; i < n3; i++ {
			b.Reset()
			b.WriteString("id=")
			b.WriteString(strconv.Itoa(i))
			out = append(out, b.String())
		}
		return len(out)
	})
	emit("gp-fmt-in-loop", "strconv_builder", "after", med3a2, n3, 1)
	emit("gp-fmt-in-loop", "fmt_sprintf_loop", "before", med3b, n3, med3b/max(med3a2, 1e-9))
	emit("gp-fmt-in-loop", "strconv_itoa_only", "after", med3a, n3, 1)
	emit("gp-fmt-in-loop", "fmt_sprintf_vs_itoa", "before", med3b, n3, med3b/max(med3a, 1e-9))

	// --- gp-append-nil-slice: append grow vs presize ---
	n4 := envInt("GP004_N", 500000)
	items := make([]int, n4)
	for i := range items {
		items[i] = i
	}
	fmt.Fprintf(os.Stderr, "gp-append-nil-slice append-grow n=%d\n", n4)
	med4a := timeMany(func() int {
		out := make([]int, 0, len(items))
		for _, v := range items {
			out = append(out, v)
		}
		return len(out)
	})
	med4b := timeMany(func() int {
		var out []int
		for _, v := range items {
			out = append(out, v)
		}
		return len(out)
	})
	emit("gp-append-nil-slice", "presize_make", "after", med4a, n4, 1)
	emit("gp-append-nil-slice", "append_grow", "before", med4b, n4, med4b/max(med4a, 1e-9))

	n4s := envInt("GP004_N_SMALL", 100)
	itemsS := items[:n4s]
	med4sa := timeMany(func() int {
		out := make([]int, 0, len(itemsS))
		for _, v := range itemsS {
			out = append(out, v)
		}
		return len(out)
	})
	med4sb := timeMany(func() int {
		var out []int
		for _, v := range itemsS {
			out = append(out, v)
		}
		return len(out)
	})
	emit("gp-append-nil-slice", "small_presize", "after", med4sa, n4s, 1)
	emit("gp-append-nil-slice", "small_append_grow", "before", med4sb, n4s, med4sb/max(med4sa, 1e-9))

	// --- gp-defer-in-loop: defer in loop vs close each ---
	// Synthetic closer; avoid real FS.
	n5 := envInt("GP005_N", 20000)
	fmt.Fprintf(os.Stderr, "gp-defer-in-loop defer-loop n=%d\n", n5)
	type closer struct{ n *int }
	closeFn := func(c *closer) { *c.n++ }

	med5a := timeMany(func() int {
		s := 0
		for i := 0; i < n5; i++ {
			c := &closer{n: &s}
			closeFn(c)
		}
		return s
	})
	med5b := timeMany(func() int {
		s := 0
		func() {
			for i := 0; i < n5; i++ {
				c := &closer{n: &s}
				defer closeFn(c)
			}
		}()
		return s
	})
	emit("gp-defer-in-loop", "close_each", "after", med5a, n5, 1)
	emit("gp-defer-in-loop", "defer_in_loop", "before", med5b, n5, med5b/max(med5a, 1e-9))

	n5s := envInt("GP005_N_SMALL", 100)
	med5sa := timeMany(func() int {
		s := 0
		for i := 0; i < n5s; i++ {
			c := &closer{n: &s}
			closeFn(c)
		}
		return s
	})
	med5sb := timeMany(func() int {
		s := 0
		func() {
			for i := 0; i < n5s; i++ {
				c := &closer{n: &s}
				defer closeFn(c)
			}
		}()
		return s
	})
	emit("gp-defer-in-loop", "small_close_each", "after", med5sa, n5s, 1)
	emit("gp-defer-in-loop", "small_defer_in_loop", "before", med5sb, n5s, med5sb/max(med5sa, 1e-9))

	// write per-rule jsonl
	byRule := map[string]*strings.Builder{}
	for _, L := range all {
		b := byRule[L.rule]
		if b == nil {
			b = &strings.Builder{}
			byRule[L.rule] = b
		}
		fmt.Fprintf(b, `{"rule":"%s","case":"%s","role":"%s","go":"%s","median_ms":%.6f,"ops":%d,"ratio":%.6f,"ts":"%s"}`+"\n",
			L.rule, L.caseName, L.role, goVer, L.med, L.ops, L.ratio, ts)
	}
	for rule, b := range byRule {
		path := filepath.Join(outDir, rule+".jsonl")
		if err := os.WriteFile(path, []byte(b.String()), 0o644); err != nil {
			panic(err)
		}
		fmt.Fprintf(os.Stderr, "wrote %s\n", path)
		fmt.Print(b.String())
	}
}

func max(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}
