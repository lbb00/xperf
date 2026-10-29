//go:build ignore

package good

func collect(items []int) []int {
	out := make([]int, 0, len(items))
	for _, v := range items {
		out = append(out, v)
	}
	return out
}
