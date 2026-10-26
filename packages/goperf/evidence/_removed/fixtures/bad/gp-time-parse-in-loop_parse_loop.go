package bad

import "time"

func parseAll(rows []string) int {
	n := 0
	for _, row := range rows {
		if _, err := time.Parse(time.RFC3339, row); err == nil {
			n++
		}
	}
	return n
}
