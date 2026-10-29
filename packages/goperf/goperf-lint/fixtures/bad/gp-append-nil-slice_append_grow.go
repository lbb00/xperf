//go:build ignore

package bad

func collect(items []int) []int {
	var out []int
	for _, v := range items {
		out = append(out, v)
	}
	return out
}
