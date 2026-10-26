package bad

import "encoding/json"

func sizes(blob []byte, n int) int {
	s := 0
	for i := 0; i < n; i++ {
		var v map[string]int
		_ = json.Unmarshal(blob, &v)
		s += len(v)
	}
	return s
}
