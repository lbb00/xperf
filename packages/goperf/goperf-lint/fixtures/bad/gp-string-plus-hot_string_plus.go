//go:build ignore

package bad

func join(parts []string) string {
	s := ""
	for _, p := range parts {
		s += "" + p
	}
	return s
}
