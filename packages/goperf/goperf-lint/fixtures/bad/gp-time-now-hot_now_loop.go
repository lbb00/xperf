//go:build ignore

package bad

import "time"

func bad(n int) int64 {
	var s int64
	for i := 0; i < n; i++ {
		s = time.Now().UnixNano()
	}
	return s
}
