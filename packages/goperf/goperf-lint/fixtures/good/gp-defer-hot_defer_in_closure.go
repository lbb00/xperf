//go:build ignore

package good

func register(paths []string) []func() {
	out := make([]func(), 0, len(paths))
	for _, p := range paths {
		path := p
		out = append(out, func() {
			defer func() { _ = path }()
			_ = path
		})
	}
	return out
}
