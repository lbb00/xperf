package p

import "time"

func good(n int) int64 {
	t := time.Now().UnixNano()
	var s int64
	for i := 0; i < n; i++ {
		s = t
	}
	return s
}
