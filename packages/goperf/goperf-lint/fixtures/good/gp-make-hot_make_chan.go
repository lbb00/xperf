//go:build ignore

package good

func fanout(n int) []chan struct{} {
	out := make([]chan struct{}, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, make(chan struct{}))
	}
	return out
}
