package good

import "regexp"

func match(lines []string) int {
	n := 0
	for _, line := range lines {
		re := regexp.MustCompile(line)
		if re.MatchString(line) {
			n++
		}
	}
	return n
}
