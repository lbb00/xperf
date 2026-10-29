//go:build ignore

package bad

import "os"

func bad(path string, n int) int {
	s := 0
	for i := 0; i < n; i++ {
		f, err := os.Open(path)
		if err != nil {
			return s
		}
		var buf [8]byte
		k, _ := f.Read(buf[:])
		_ = f.Close()
		s = k
	}
	return s
}
