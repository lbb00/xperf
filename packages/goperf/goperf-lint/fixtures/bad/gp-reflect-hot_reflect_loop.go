//go:build ignore

package bad

import "reflect"

type S struct{ A int }

func bad(s S, n int) int {
	name := "A"
	t := reflect.TypeOf(0)
	acc := 0
	for i := 0; i < n; i++ {
		acc += int(reflect.ValueOf(s).FieldByName(name).Int())
		_ = reflect.New(t)
	}
	return acc
}
