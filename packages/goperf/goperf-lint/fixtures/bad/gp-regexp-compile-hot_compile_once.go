//go:build ignore

package bad

import "regexp"

func match(lines []string) int {
	re := regexp.MustCompile("a+")
	n := 0
	for _, line := range lines {
		if re.MatchString(line) {
			n++
		}
	}
	return n
}
