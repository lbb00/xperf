package good

import "encoding/json"

func sizes(blob []byte) int {
	var rows []map[string]int
	_ = json.Unmarshal(blob, &rows)
	n := 0
	for _, row := range rows {
		n += len(row)
	}
	return n
}
