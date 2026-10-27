package good

import "fmt"

func label(i int) string {
	return fmt.Sprintf("id=%d", i)
}

func labels(n int) []string {
	out := make([]string, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, label(i))
	}
	return out
}
