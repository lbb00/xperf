//go:build ignore

package bad

import "regexp"

func match(lines []string) int {
	n := 0
	for _, line := range lines {
		re := regexp.MustCompile("a+")
		if re.MatchString(line) {
			n++
		}
	}
	return n
}
