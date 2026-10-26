package good

import "os"

func good(files []string) int {
	s := 0
	for i := 0; i < len(files); i++ {
		f, err := os.Open(files[i])
		if err != nil {
			return s
		}
		_ = f.Close()
		s++
	}
	return s
}
