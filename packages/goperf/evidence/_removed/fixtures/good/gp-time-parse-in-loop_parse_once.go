package good

import "time"

func parseAll(rows []string) int {
	n := 0
	_, _ = time.Parse(time.RFC3339, rows[0])
	for _, row := range rows {
		_, _ = time.ParseInLocation(time.RFC3339, row, time.UTC)
		_ = time.Now()
		if row != "" {
			n++
		}
	}
	return n
}
