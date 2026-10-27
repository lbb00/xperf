package bad

import "fmt"

func labels(n int) []string {
	out := make([]string, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, fmt.Sprintf("id=%d", i))
	}
	return out
}
