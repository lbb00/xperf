package main

import (
	"fmt"
	"strings"
)

func main() {
	var b strings.Builder
	for i := 0; i < 8; i++ {
		b.WriteByte(byte('a' + i))
	}
	fmt.Println(b.String())
}
