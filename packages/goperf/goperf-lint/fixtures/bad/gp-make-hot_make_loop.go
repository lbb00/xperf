//go:build ignore

package bad

func fill(n int) [][]byte {
	var out [][]byte
	for i := 0; i < n; i++ {
		b := make([]byte, 64)
		out = append(out, b)
	}
	return out
}
