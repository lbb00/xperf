//go:build ignore

package good

import "encoding/json"

func sizes(rows [][]byte) int {
	s := 0
	for _, row := range rows {
		var v map[string]int
		_ = json.Unmarshal(row, &v)
		s += len(v)
	}
	return s
}
