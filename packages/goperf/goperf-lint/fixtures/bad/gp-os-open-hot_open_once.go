package p

import "os"

func good(path string, n int) int {
	f, err := os.Open(path)
	if err != nil {
		return 0
	}
	var buf [8]byte
	k, _ := f.Read(buf[:])
	_ = f.Close()
	s := 0
	for i := 0; i < n; i++ {
		s = k
	}
	return s
}
